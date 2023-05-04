#!/bin/bash


# version 1.0. 20230315. ken woo. copyleft.

# from 0.2:
# 1. bug fixed [sed -n '/Date/,/files/p'] to [sed -n '/Date/,/\lfile/p'].
# 2. found the $IFS bug but not yet resolved.
# from 0.2a:
# 1. the altering $IFS was changed into read -r for grep processing [grep $2 -- "$ctx"].
# from 0.2b:
# 1. added time elapsed.
# 2. added a 'cp' identifier for use in $2 if want to copy to $3 directly without context match just only filename match.
# 3. added to generate a path file besides of a target file, hence this target file could be easily found manually.
# from 0.3: only add some comments.
# from 0.3r:
# 1. fixed [sed -n '/Date/,/\lfile/p'] even it affects nothing(false negative).
# 2a. changed the sed command into correct one since it sometimes failed match, [tmp_str=$( echo "$tt" | sed 's,'"$TMP_DIR"',,' )].
# 2b. it only affects the path in "path file" which would lose some intermediate path-string. the correct one uses bash internal cmd.
# 3. added "$2"=="cq" for only copying path files without target files. (since this way is simpler than outputing via std-out).
# from 0.4:
# 1. fixed [ while [ -e "${3}${k}" ] ] not concerning about path file.
# 2. added "$2"=="cr" for adding sha1sum checksum file *.cksm along with path file. to separate is easy access, e.g., "cat *.cksm".
# from 0.5:
# 1. in [ tmp_1=$( sha1sum "$ctx" | sed 's/^\([0-9a-fA-F]\+\).*/\1\ /' ) ],
#     mind changed. use path file also to have checksum when 'cr' is specified. and for less disk-w and for the filename weakness.
# from 0.5r:
# 1. sha1sum -b might be faster.
# 2. might have fixed the limitation-12 issue by using -- and prevented from using sed',,'.
# 3. it is more confortable to output path string rather than path file. added $2=='cs' for this purpose. keyword is [[[Path Here]]].
# from 0.6:
# 1. the prior versions have a spawned bug that having $2 search-pattern with $3 path but no copy events.
# 2. the 'cs' option of the previous version has wrong logic.
# 3. so, for fixing 1 & 2, it is better to have had made moderate changes of code for either keeping c[pqrs] options still effect or
#     making output to be able to show the exact path by prefixing a [[[FoundHere]]] line for if $2 is just set. then which means,
#     the original 'cs' function is no longer needed, thereby,
#     'cs' would do new behavior of adding a line checksum between [[[FoundHere]]]-line and path-line.
#     so, these new functions are updated at the next, "purposes".
# 4. so, this version is 0.7 would be the final release.
# from 0.7:
# 1. added 'ct' option. please refer to example 15.
# 2. the arguments are exclusively changed for 'ct' option from #7 to #9.
# 3. really final release.
# 1. 0.7r-1 from 0.7r: forget to remove tmp folder $arcpath after done XD
# 1. 0.7r-2 from 0.7r-1: add quote [[ ! -e "$a_rep" ]]. note that after by my test, 'ct' performance is worse.
# from 0.7r-2: the 'ct' performance problem does not cause error, but it is still code error. version 0.8 fixed this problem.
# from 0.8. present 0.9:
# 1. the 'ct' option by my test, total 3,000,000 files to copy, by split and sequential process, each round took 15,000 files.
#     the result as only 280,000 were copied, were taken 24 hours(IntelI7gen1).
#     in order to improve the 'ct' performance, ways of change code is one(unfortunately, after the code change,
#     the performance was as stated as that), and let the rounds(15000s/total) run in parallel is another.
#     a) for code change, a new argument was introduced and rearranged. this rearrangement only for 'ct' option,
#     the old 9th parameter changed to as 10th; the 9th parameter is now as the number of total target files in a source file.
#     b) as for the later parallel processes of trial, jobs go to background is the way, and the new performance data was as:
#     4 concurrent processes, 7hr40m, (15000)/280000/(3000000) files. less than 1/3 original time.
#     simply put, the 'ct' now supports over 3 million target files as in a formal-path source file with improved performance as
#     far as i could tune.
# from 0.9. present 1.0: use alternatives to prevent from chars search/replace failure; make-up/finalize. (the test, see example 16).


# purposes:
#
# only tested on Ubuntu.
#
# 1a. dig out all the "$1" files(only show results of file path/name) under current working dir/subdir and
#     including which packed within archive files even within archive of archive of archive of...
# 1b. all results are via standard output by any one of these functions.
# 1c. by this one of functions, the "path" is not the exact location if the file is within archive;
#      for demanding the exact path, using the others following functions all of which could do.
#
# 2a. the same as 1., and also search contents of the matched files by pattern "$2", which is also in grep style pattern and
#      including options, e.g., $2==".*void\ \+main\(.*\) -i -n -B5 -A5". (note, the options in trailing is must).
# 2b. if found, would be outputed in the following format:
# the-matched-line(s)
# ==========>>>>>
# [[[FoundHere]]]
# (this line is the file checksum only exists by using the 'cs' function; see 5c.)
# the-exact-path/filename
# <<<<<==========
#
# 3. the same as 2., and copy the matched files with an accompanying path file to the assigned absolute-directory by "$3".
#
# 4a. the same as 3., but directly copies without specifying context pattern in $2, instead, by setting $2 as 'cp' for this purpose.
#      note, you can try ".*" in $2 in comparison with "cp".
# 4b. another is 'cq' for copying path file only.
# 4c. yet another 'cr', 'cs'(see 5.).
#
# 5a. another path file(*.path) is unconditionally coming up with the copied target file.
# 5b. use $2=='cr' to not only 'cq' but also add checksum of the target file in the path file.
# 5c. use $2=='cs' to std-output file checksum; see 2b.-format; and no any copy event, only std-output.
#
# 6. note that generating the path file is the old-school function, kept for compt., except 1c., all done well via std-output.
#
# 7a. please refer to example 15. it does not realize about deflating upon these specific target files in an archive, instead,
#     it extracts whole archive. however, each concerning archive only extracted once since the list is sorted before processing.
# 7b. so, it is the 'ct' option does; now supporting single formal-path source file with over 3 million files(verified).
# 7c. which realized/perf.-tuned by dividing into background concurrent processes however, high probability of same archives would
#      loaded couple of times where performance and especially free space are seriously sacrificed during processing.
#      so $CT_NUM_TO_SPLIT_L(should not too less), $CT_BG_PROCESSES(should not too many) must awareness of set properly.


# required:
# 1. apt install p7zip-full p7zip-rar
# 2. in the /tmp/ dir for extracting files for temporary use, auto deleted after done.
# 3. while processing 'ct', a temp file job.lock is generated in $PWD; should leave it alone(better to run in $TMP).
# 4. while processing 'ct', highly recommended the formal-path source file put in the temp/ram since it is all-the-time accessing.
# 5. while processing 'ct', $CT_BG_PROCESSES determines maximum of for example, "a.7z" extracted is 1G, 4 means 5G might consumed.


# known limitation:
# 1. the search pattern is in grep format.
# 2. search twice if the soft-link and its real-path are both in the searching-paths.
# 3. multi-volume archive will cause 7z to exit. so rename existing ones are needed before running this script into completely.
# 4. it is used by "7z -px" to skip password protected archives.
# 5. it is used by "7z -aou" to auto rename repetitive extracted files.
# 6. token 'null' is used, so it is not for pattern search. so is the 'cp', 'cq', 'cs', and 'cr' in $2.
# 7. file descriptor 3 is used for identification purpose, so do not use it before running this script.
# 8. except parameters $1, $2, $3 are for user, the other params are only for internal use:
#     "$4" passing a specific archive file for extracting and searching.
#     "$5" script path.
#     "$6" script name.
#     "$7" progressive path for inheriting.
# 9. $2, the content pattern, must have the options in trailing. that is like as "the_pattern -opt1 -opt2".
# 10. the target path for copying can not be in the searching path or it might be searched and cause loop.
# 11a. $2 has 5 identifiers 'null' and 'c[pqrs]' can not be used, however, still could be the pattern by e.g., "nul[l]\{1\}".
# 11b. note, weird: [grep nul[l]\{1\} -n --color a.txt] is failed and [this_script ".*a\.txt.*" "nul[l]\{1\} -n --color"] is success.
# 11c. $1 needs full qualified name, that is, if "a.txt" is exactly the file to search, it still needs to be like as ".*a\.txt.*"
# 11d. the 11c might be the reason of prefixed path.
# 12a. known fault: the filenames to inspect if containing 1) comma "," 2) leading hyphen "-" etc., either made sed fault or bash fault.
# 12b. this issue might be fixed beginning from ver.0.6.
# 13a. for the 'ct' option, by my test could handle 23000 files in a round. and it might be the upper bound and over should avoid.
# 13b. this limitation overcame by using concurrent processes beginning from v.0.9. however drawback is same-file overloaded seriously.
# 14. for the 'ct' option, known issue: 1) intermediate archive names containing brackets would not copy; [, ]. (overcame by v.1.0).
#      2) filenames beginning by a dot will not copy, e.g., ".the_file.txt". currently no idea. (not fixed but not true by v.1.0).
#      3) pathnames/filenames containing back-slash would cause 'ct' abnormal fault; the same as for other options uncertain/not tested.
# 15. for the 'ct' option, suppose minimal time 0.1 seconds for processing a file, 3000000 files will take 83 hours. so ct optimiz-ing.
# 16. for the 'ct' option, $CT_NUM_TO_SPLIT_L should not too small or cause the same archive overloaded. however could be 1 be fine
#      in such the case that each archive having only 1 file or extracting only 1 file from each archive.
# 17. for the 'ct' option, great amount of files were tested that it could handle any char of path/file names though, still had events
#      on results of "file not found(3)". no clue to fix as far as i know. manually post-treat is recommended.


# example1: [this_script ".*\.pdf$"]
#     find out all the "pdf" files where locate including sub-dirs and within archive files.
#
# example2: detach the task from shell for free run.
# [sudo nohup this_sh ".*\.pdf$\|.*\.doc$\|.*\.chm$\|.*\.djvu$\|.*\.pptx\?$\|.*\.pps$\|.*\.xlsx\?$\|.*\.mht$" &> ~/Output.txt & disown]
#
# example3: [this_script ".*\.c$" ".*printf.* -n -B3 -A5"]
#     find out all the "*.c" files which have pattern '.*printf.*' in it. and
#     also dump out these line-number and the before 3 lines and the after 5 lines.
#
# example4: [this_script ".*\.c$" ".*printf.* -n -B3 -A5" /home/user/Desktop/target]
#     the same as example3 and copy matched files(with path files) to folder /home/user/Desktop/target/.
#
# example5: [this_script .*\.txt$ "[^[:blank:]]\+Group[[:blank:]]\{1\} -n -i -A5 -B4 --color" /home/user/Desktop/temp/]
#
# example6: [this_script .*\.txt$ cp /home/user/Desktop/temp/]
#     all the found *.txt files with .path files will directly copy to /home/user/Desktop/temp/.
#
# example7: "the_copied_target.file" has a companion file "the_copied_target.file.path" unconditionally. so, rm *.path if not required.
#
# example8: [cat outputfile | sed '/^\(-\|=\)\+>\+\|^<\+=\+\|^[\(Open \)\(ERROR\)\(WARNINGS\)\(\[\[\[Found\)]\|^Is not archive/d;/^$/d;s/\(\/.*\/\)\([^\/]\+$\)/\2/']
#     extract only filenames from result output. note, 7z-error/-open-error files may just not supported, so need to treat by other ways.
#
# example9: [this_script ".*\.\(zip\|rar\|ace\|arj\|t\?gz\|tar\|z\|7z\|bz2\|lzh\|txt\|ex[e_]\{1\}\|bat\|msi\|sys\|dll\|ocx\|bin\|pdf\|djvu\|html\?\|mht\|chm\|css\|js\|ps\|iso\|nrg\|gho\|cab\|avi\|rm\(vb\)\?\|jpe\?g\|bmp\|ico\|gif\|mp[34]\{1\}\|mpe\?g\|png\|doc\|ini\|hlp\|inf\|ttf\|pptx\?\|pps\|xlsx\?\|reg\|dat\|db\|bak\|log\|asm\|inc\|c\(pp\|xx\)\?\|h\(pp\)\?\|lib\)$" &> output.txt]
#
# example10: [find . -iname "*.path" -exec cat {} >> output.txt \;] if huge amount of files cause [cat * >> output.txt] failed.
#
# example11: [./this_script ".*\.\(c\|cpp\)$" "(?s)(int|void)[[:space:]]*main[[:space:]]*\([^\)]*\)[[:space:]]*{.* -izaPo --color" | sed 's/\x0//' > Dump.txt]
# dig out all the main function definitions.
# note the [sed 's/\x0//'], not only 1 occurrence for using this script however, only 1 occurrence when using single grep, that is,
# [sed '$s/\x0//'] is enough.
#
# example12: using 'cs', if do not want to have checksum, comment out this sha1sum generating line in if-cs code block.
#
# example13: [sed '/^\(-\|=\)\+>\+\|^<\+=\+\|^\[\[\[Found\|^[0-9a-fA-F]\+$\|^\/.*/d;/^$/d;=' native.txt | sed 'N;s/\n/ /' > output.txt]
#     suppose a native.txt is generated by 'cs' option, then we want to check out(extract) all of the errors. line number is prefixed for grouping-able.
#
# example14: [ grep "^\/" native.txt > output.txt]
#     suppose a native.txt is generated by 'cs' option, extract all the path/filename is simple.
#
# example15: [ ./this_script full_paths_in_this.file "ct" target_path_for_copy_to ]
#     since to get a file each time by a thorough search upon some location is funny. better method is to generate a map upon it.
#     that is, the 'cs' option with $1="anything_interested" done so.
#     suppose a native.txt is generated by 'cs' option; which is a text file storing all interested files of full-path/filenames.
#     then we get some full-paths of present of interests out of this map and collect to the file "full_paths_in_this.file",
#     each full-path in one-another line. then this "ct" option would extract/copy these files to the "target_path_for_copy_to".
#
# example16: the detailed test data, by SERF v.1.0; perform 'ct' on sources from 'cs' with ".*" files;
#                source files total 5,352 files, 277G; deflated total 3,044,421 files.
#     IntelI7gen1: 15,000/3,044,421, concurrent processes: 2, 16hr17min, 280,000 done, unfinished.
#     AMDz3r9-5900HX: in average 65Watt(reduced full-speed during processing), 17hr47min, 15,000/3,044,421,
#         concurrent processes: 15, file not found(3)=1,322, remaining 7z reported errors, excellently finished.


SERF_VER="Bash 4.3+ script. SERF version 1.0"

# the following 4 defaults as 15000, 2500, 33000, 10.
# especially note that the 'ct' performance bottleneck is just the "total source files", more files affects bash much more clumsy.
# that is why the splitting gets considerable performance improvement.
CT_NUM_TO_SPLIT_H=15000  # 23000 is max for dry run; more total target files, further less than 23000. 15000 v.s. 3000000 is ok.
CT_NUM_TO_SPLIT_L=120   # be the LOW chunk for use; else use CT_NUM_TO_SPLIT_H.
CT_NUM_USE_LOW=33000     # if the number of total target files less than this threshold, apply the CT_NUM_TO_SPLIT_L for each chunk.
CT_BG_PROCESSES=22       # the number of parallel processes at most. how many used as for disk space and ram should be considered.

        function MYGUBED() {
            return;
            echo -e "\n<debug>"
            for var in "$@"; do
                [[ $var =~ ^-+ ]] && echo ${var#-}
            done
            for myvars in "$@"; do
                [[ $myvars =~ ^-+ ]] && continue
                echo "<debug> \$$myvars: ${!myvars}"
            done
            echo
        }

        # https://stegard.net/2022/05/locking-critical-sections-in-shell-scripts/
        function lock_acquire() {
            # Open a file descriptor to lock file. return 1 if exception occurred.
            exec {LOCKFD}>job.lock || return 1

            # Block waiting until an exclusive lock can be obtained on the file descriptor
            flock -x $LOCKFD
        }

        function lock_release() {
            test "$LOCKFD" || return 1

            # Close lock file descriptor, thereby releasing exclusive lock
            exec {LOCKFD}>&- && unset LOCKFD
        }

        #lock_acquire || { echo >&2 "Error: failed to acquire lock"; exit 1; }
        # --- Begin critical section ---

        # --- End critical section ---
        #lock_release

        function mycp1() {    # $1 is the target path; std-input is the src file path
            while read -r in; do
            if [ -e "$in" ]; then
                i=0;
                j=$( basename -- "$in" )
                k=$j

                lock_acquire || { echo >&2 "Error: failed to acquire lock"; exit 1; }
                while [ -e "${1}${k}" ] || [ -e "${1}${k}.path" ]; do
                    (( i=$i+1 ));
                    k="$j($i)"
                done
                cp -- "$in" "${1}${k}"
                echo "$in" > "${1}${k}.path"
                lock_release

                echo " ";    # pass forward. it is in order to keep the source ordered
            else
                echo "$in";    # pass forward. it must be invalid or in archive
            fi
            done
        }

        function mycp2() {    # $1 is the target path; $2 is formal path; std-input is the src file path
            while read -r in; do
            if [ -e "$in" ]; then
                i=0;
                j=$( basename -- "$in" )
                k=$j

                lock_acquire || { echo >&2 "Error: failed to acquire lock"; exit 1; }
                while [ -e "${1}${k}" ] || [ -e "${1}${k}.path" ]; do
                    (( i=$i+1 ));
                    k="$j($i)"
                done
                cp -- "$in" "${1}${k}"
                echo "$2" > "${1}${k}.path"
                lock_release

                return 0;
            else
                return 1;
            fi
            done
        }

        # target files which could direct copy are copied beforehand and other than files in the $lines which need more treatments.
        # the $lines is a sorted lines in number, e.g., [7,9,17,5,2,], each line contains at least 1 intermediate archive path/name,
        # while processing, these real archive files locate at the course of real path(call it formal path) while is in root task,
        # or at the course beginning from later generated tmp dir while is in sub tasks;
        # $a_rep for handling these 2 conditions to locate either real files.
        # $a_map is a part of the formal path corresponding to $a_rep in order to one-shot replacement.
        # parameters are using pass-by-var-name for global vars could be used both into this function and for return. bash 4.3 later.
        # at each round, $lines fans out the line(s) having a first common archive or is standalone. so it is shrinked after called;
        # whose are moved to $a_num(having common archive). $a_rep is "" when is in root task for handling formal path;
        # when in a child task it is an extracted archive root path via tmp path, e.g., /tmp/DataFile.zip.XXXXXXXX/,
        # and it corresponds to the $a_map which is a part of formal path from the formal-paths source-file which is $1.
        # and $a_map finally becomes the first-intermediate archive path for return. $a_num is the fan out line(s) for sub-task call.
        # note the 3 vars $3/$4/$5 should be passed by var-names. (now $5 changed to $6)
        # $1 is the collect of formal paths file, $2==$a_rep the extracted archive tmp path, $3==$a_map, $4==$a_num, $6==$lines.
        # after called, $3==part of formal path advanced to the next intermediate archive, $6==the $lines subtracted by $4==$a_num.
        # $5==the number of total target files. since faster commands tail~=sed < head. if location exceeds half of the total,
        # tail command is the better choice than sed.
        # keep in mind at this entrance moment, files are ready for looking up.
        function myFanOut() {
            a_rep=$2
            local -n a_map=$3
            local -n a_num=$4
            #local -n lines=$5
            local -n lines=$6

            #a_num=$( sed -n 's/\(^[0-9]\+\),.*/\1/p' <<< $lines )                # get the leading number "i"
            a_num=$( xxd -l 16 <<< $lines | sed -n 's/.* \([0-9]\+\),.*/\1/p' )  # improve the previous line code. 15-digit number.

            #a_pathfile=$( sed "${a_num}q;d" "$1" )                               # exactly the i-th line in formal path file
	    (( ${a_num} < ${5} / 2 )) && a_pathfile=$( sed "${a_num}q;d" "$1" ) || \
                a_pathfile=$( tail -n $(( ${5}-${a_num}+1 )) "$1" | head -n 1 )  # improve the previous line code.

            lines=${lines#?*,}                                                   # discard it from $lines
            #a_pathfile="${a_rep}${a_pathfile#$a_map}"                            # the real existing location of this file
            a_pathfile="${a_rep}${a_pathfile:${#a_map}}"                          # alternative to eliminate failure cut.

            # after this loop, $a_rep would be empty or an imtermediate archive
            while true; do
                tgt_1="$a_rep"

                # this workaround consumes performance to support [ and ]. it is hard to decide since these chars are uncommon.
                #a_rep=$( expr match "$a_pathfile" "\(${a_rep}/[^/]\+\).*" )      # level by level cd into.
                a_rep_tmp=$( sed 's/\[/\\\[/g;s/\]/\\\]/g' <<< "${a_rep}" )
                a_rep=$( expr match "$a_pathfile" "\(${a_rep_tmp}/[^/]\+\).*" )

                if [ "$tgt_1" == "$a_rep" ]; then                                # tail; true should copied. false wrong formal.
                    if [ -e "$a_rep" ]; then
                        echo "found but error\; nothing done(1 logic error): $a_num $a_pathfile" >&2
                    else echo "file not found(2 formal path error): $a_num $a_pathfile" >&2
                    fi
                    a_rep=""
                    break
                fi    # so why thus not see
                if [[ ! -e "$a_rep" ]]; then                                     # where to stop
                    if [ -f "$tgt_1" ]; then                                     # where we want
                        a_rep="$tgt_1"
                        break;
                    fi
                    a_rep=""                                                     # ! possibly 2 cases non-/existing directory,
                    echo "file not found(3): $a_num $a_pathfile" >&2             # ! which might caused by extraction error,
                    break                                                        # ! and 3rd case is wrong formal path.
                fi
            done    # so why thus not see
            [[ "${a_rep}" == "" ]] && return 1;

            #a_map="${a_map}${a_rep#$2}"                                          # cast back to advanced incremented formal path.
            a_map="${a_map}${a_rep:${#2}}"                                       # a safe workaround

            a_num="${a_num},"                                                    # into correct format
            while [[ $lines != "" ]]; do

                #b_num=$( sed -n 's/\(^[0-9]\+\),.*/\1/p' <<< $lines )            # collect all the same intermediate formal paths.
                b_num=$( xxd -l 16 <<< $lines | sed -n 's/.* \([0-9]\+\),.*/\1/p' )    # improve the previous line code.

                #b_pathfile=$( sed "${b_num}q;d" "$1" )
                (( ${b_num} < ${5} / 2 )) && b_pathfile=$( sed "${b_num}q;d" "$1" ) || \
                    b_pathfile=$( tail -n $(( ${5}-${b_num}+1 )) "$1" | head -n 1 )

                #if [[ "$b_pathfile" = "${a_map}.*" ]]; then                     # should be [[ $b_pathfile =~ ${a_map}.* ]],
                # however it is still wrong since some special characters in path/filename unable escape.
                #tmpx=$( expr match "${b_pathfile}" "\(${a_map}\)" )
                # this workaround consumes performance to support [ and ]. it is hard to decide since these chars are uncommon.
                a_map_tmp=$( sed 's/\[/\\\[/g;s/\]/\\\]/g' <<< "${a_map}" )
                tmpx=$( expr match "${b_pathfile}" "\(${a_map_tmp}\)" )

                if [ $? -eq 0 ]; then

                    a_num="${a_num}${b_num},"
                    lines=${lines#?*,}
                else break
                fi
            done
            return 0;
        }


lsof -a -p $$ -d 3 2>/dev/null | grep -i -q "\ 3w\ \|\ 3u\ "    # use file descriptor 3 for recognizing root

if [ $? -eq 0 ]; then                                   # if not the root task

    if [ $# -ge 7 ]; then                               # if intends for fork-task
        inipath=$( pwd )
        arcname="$( basename -- "$4" ).XXXXXXXX"
        arcpath=$( mktemp -t -d -- "$arcname" )

        # failed: almost case is no free space, exit but not terminated since the space whom consumed will free it back automatically.
        #  so, if see this error message, which means this execution is incomplete, and needs redo and needs more free space or
        #  needs to decrease concurrent processes which more ones cause more disk space consumption/same archive greatly overloaded.
        [[ $? -ne 0 ]] && { echo "ERROR: $SERF_VER: probably ran out of available space." >&2; exit 1; }

        SCRIPT_DIR="$5"
        SCRIPT_NAME="$6"
        INI_DIR="$7"
        TMP_DIR="$arcpath"


    # AAAAA for handling the 'ct' option
    if [ "$2" = ct ]; then

                MYGUBED "-________________________" "-$( echo ${8} )" "-$( echo ${4} )" # in case of 7z failed for tracing.

        7z -px -aou -o"$arcpath" x -- "$4" 1>/dev/null  # no masking error since what had handled was on the map which succeeded.
        d_num=""
        #all_num=$9
        all_num="${10}"

        while [[ $all_num != "" ]]; do

            #c_num=$( sed -n 's/\(^[0-9]\+\),.*/\1/p' <<< $all_num )
            c_num=$( xxd -l 16 <<< $all_num | sed -n 's/.* \([0-9]\+\),.*/\1/p' )

            #c_pathfile=$( sed "${c_num}q;d" "$1" )
            (( ${c_num} < ${9} / 2 )) && c_pathfile=$( sed "${c_num}q;d" "$1" ) || \
                c_pathfile=$( tail -n $(( ${9}-${c_num}+1 )) "$1" | head -n 1 )

            #c_formalpath="$8${4#$INI_DIR}"
            c_formalpath="$8${4:${#INI_DIR}}"

                #za=$4; MYGUBED "-==========================" "-$( echo ${arcpath}${c_pathfile#$c_formalpath} )" \
                    #c_num c_pathfile c_formalpath za INI_DIR all_num

            #d_pathfile="${arcpath}${c_pathfile#$c_formalpath}"
            d_pathfile="${arcpath}${c_pathfile:${#c_formalpath}}"

            all_num=${all_num#?*,}
            mycp2 "${3}" "${c_pathfile}" -- <<< "$d_pathfile" || d_num="${d_num}${c_num},"
        done
        while [[ $d_num != "" ]]; do
            arg_3=$c_formalpath
            arg_4=""
            myFanOut "$1" "$arcpath" arg_3 arg_4 "$9" d_num
            if [ $? -eq 0 ]; then

                #MYGUBED "-------------------------" "-$( echo $arcpath${arg_3#$c_formalpath} )" arcpath arg_3 arg_4

                #"$SCRIPT_DIR"/"$SCRIPT_NAME" "$1" "$2" "$3" "$arcpath${arg_3#$c_formalpath}" "$SCRIPT_DIR" "$SCRIPT_NAME" \
                    #"$arcpath" "$c_formalpath" "$9" "$arg_4"
                # since the replacement has chance failed because of special characters.
                "$SCRIPT_DIR"/"$SCRIPT_NAME" "$1" "$2" "$3" "$arcpath${arg_3:${#c_formalpath}}" "$SCRIPT_DIR" "$SCRIPT_NAME" \
                    "$arcpath" "$c_formalpath" "$9" "$arg_4"

            fi
        done
        rm -rf -- "$arcpath"
        exit 0
    fi
    # VVVVV for handling the 'ct' option


        7z -px -aou -o"$arcpath" x -- "$4" 2>/dev/null 1>/dev/null
        cd -- "$arcpath"
    else                                                # something wrong
        exit 1
    fi

else                                                    # the root task, generates fd3

    # trap prevents from aborted by user and $IFS not yet recovered
    IFS_OLD="$IFS"
    function for_trap_exit() {
        echo -e '\n\nuser abort\n';
        [[ "$IFS_OLD" != "$IFS" ]] && IFS="$IFS_OLD" && echo clean up;
        # be careful not to clean-up /tmp/ here or get into catastrophe since I met.
        exec 3>&-;
        exit 1;
    }
    trap for_trap_exit SIGINT SIGKILL SIGSEGV

    # wrong arguments
    if [ $# -lt 1 ] || [ $# -gt 3 ]; then
        echo; echo "usage: ${0} \"filename pattern for search\" [\"context pattern in file\" [\"path to extract if match\"] ]";
        exit 1
    fi

    # no 7z bin file
    7z | grep -i "copyright"
    if [ $? -ne 0 ]; then
        echo; echo "utility 7z is needed. please try \"apt install p7zip-full p7zip-rar\" first.";
	exit 1
    fi

    # set global vars
    SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    SCRIPT_NAME=$( basename -- "${BASH_SOURCE[0]}" )
    TMP_DIR="presently working directory"
    INI_DIR=""
    inipath=$( pwd )
    arcpath=$( pwd )

    # rearrange arguments
    z1="$1"
    if [ $# -eq 1 ]; then
        z2='null'
        z3='null'
    elif [ $# -eq 2 ]; then
        if [ "$2" = 'null' ]; then
            echo '"null" not applicable.'
            exit 1
        elif [[ "$2" = c[pqrt] ]]; then
            echo "the absolute path is needed."
            exit 1
        fi
        z2="$2"
        z3='null'
    else
        if [ "$2" = 'null' ] || [ "$3" = 'null' ]; then
            echo '"null" not applicable.'
            exit 1
        fi
        z2="$2"
        z3="$3"
        echo "$z3" | grep -q "^/.*"
        if [ $? -eq 0 ] && [ -d "$z3" ]; then

            # try to padding "/"
            echo "$z3" | grep -q ".*/$"
            [[ $? -ne 0 ]] && z3="${z3}/"

        else
            echo; echo "the absolute path is needed."; echo;
            exit 1
        fi
    fi

    set --
    set "$z1" "$z2" "$z3"
    exec 3>&1

    echo -e "\nscript version: $SERF_VER\n"
    echo "cmd: $SCRIPT_DIR/$SCRIPT_NAME '$1' '$2' '$3'"
    echo "pwd: $inipath"

    echo; echo $( date ); echo;
    elapse_time_b=$SECONDS


    # AAAAA for handling the 'ct' option
    if [ "$2" = ct ]; then

        MY_TLINE=$( wc -l "$1" | grep -o "^[0-9]\+" )   # the total number of target files.

        # sorting into sorted lines by e.g., the result of [7,9,17,5,2,].
        # then use [sed -n 's/\(^[0-9]\+\),.*/\1/p' <<< $var] to get a line; [sed "${i-th}q;d"] to map a line;
        # $var=${var#?*,} to del a line; inc_p=$( expr match "$full_p" "\(${inc_p}/[^/]\+\).*" ) to get the incremental path;
        # especially note that by my test, 23000 path lines is about to the upper bound could be passed as the argument $9.
        sorted_lines0=$( cat "$1" | mycp1 "${3}" -- | sed '=;s/\(.*\/\)[^\/]\+$/\1/' | sed 'N;s/\n/ /' |\
            sed '/^[0-9]\+[[:blank:]]\+$/d' | sort -k2 | sed 's/\(^[0-9]\+\).*/\1,/' | sed ':a;N;$!ba;s/\n//g' );


                ##### AAA # this snippet is addon for splitting input and for parallel run
                split_nsrc=$( sed 's/\,/\ /g' -- <<< $sorted_lines0 | wc -w )                       # the number of entire targets

                [[ ${CT_NUM_USE_LOW} -gt ${split_nsrc} ]] && CT_NUM_TO_SPLIT_H=${CT_NUM_TO_SPLIT_L} # choose LOW or HIGH

                echo -e "\n'ct' option: each round $CT_NUM_TO_SPLIT_H/$split_nsrc, concurrent processes: $CT_BG_PROCESSES.\n"

                while [[ $split_nsrc -gt 0 ]]; do                                                   # the mainloop start
                    [[ ${CT_NUM_TO_SPLIT_H} -gt ${split_nsrc} ]] && CT_NUM_TO_SPLIT_H=${split_nsrc} # the last one round or not
                    (( split_nsrc=${split_nsrc}-${CT_NUM_TO_SPLIT_H} ))                             # count of remaining un-processed
                    sorted_lines="$( cut -d',' -f1-${CT_NUM_TO_SPLIT_H} <<< $sorted_lines0 ),"      # current to proceed
                    len_cur=${#sorted_lines}                                                        # processing-string for subtract
                    sorted_lines0=${sorted_lines0:len_cur}                                          # items of remaining un-processed
                ##### VVV # this snippet is addon for splitting input and for parallel run


        while [[ $sorted_lines != "" ]]; do
            arg_3=""
            arg_4=""
            arg_5=$arg_3
            tmparc=""
            myFanOut "$1" "" arg_3 arg_4 "$MY_TLINE" sorted_lines
            if [ $? -eq 0 ]; then
                # next step is to recursively handle intermediate archive either the one next to the other(while-loop) or
                # the one advanced to the other(recursive) that is what called fanout.
                # as for the following call, arg_3 for part-formal-path & arg_4($9) for same-archive candidates are not enough,
                # arg_5 is as the $8 to be the old-arg_3 inevitably needed too; so does a tmp-dir $7; to be more specific,
                # the below $arg_3 should be the ${root/tmparc}${arg_3#$arg_5}; $7==$tmparc.
                # so, commence from this point, the tasks grow number of vars from 7 to 9.
                "$SCRIPT_DIR"/"$SCRIPT_NAME" "$1" "$2" "$3" "$arg_3" "$SCRIPT_DIR" "$SCRIPT_NAME" \
                    "$tmparc" "$arg_5" "$MY_TLINE" "$arg_4"
            fi
        done &  # turn it to background for nonblocking; in order for splitting input and for parallel run


                ##### AAA # this snippet is addon for splitting input and for parallel run
                    while true; do
                        jobs -l > /dev/null    # workaround for the next line as expected
                        [[ $( jobs -l | grep "\[[0-9]\+\]" | wc -l ) -le ${CT_BG_PROCESSES} ]] && break || sleep 3;
                    done
                done    # the mainloop end

                while true; do    # wait for all background processes done
                    jobs -l > /dev/null    # workaround for the next line as expected
                    [[ $( jobs -l | grep "\[[0-9]\+\]" | wc -l ) -eq 0 ]] && break || sleep 8;
                done

                rm job.lock
                ##### VVV # this snippet is addon for splitting input and for parallel run


        exec 3<&-                                       # done the search and release fd3
        echo; echo $( date ); echo;
        (( time_elapsed=$SECONDS-$elapse_time_b ));
        echo -e "\nit took $(( $time_elapsed / 60 )) minute(s) $(( $time_elapsed % 60 )) seconds\n";

        exit 0;
    fi
    # VVVVV for handling the 'ct' option


fi


if [ "$2" != $'null' ]; then                            # needs for context search or direct-copy
    find -L ~+ -type f -regextype grep -iregex "$1" | while read -r ctx;
    do

        if [ "$2" = 'cs' ]; then                        # only standard output the checksum and the path

            # generate the path of the copied file
            # note the current file is in /tmp/arc-name/path-in-arc, so we need path-in-arc string
            # however it might be in the $PWD instead, so use sed to cover both conditions
            #tmp_str=$( echo "$ctx" | sed 's,'"$TMP_DIR"',,' )    # remove the "/tmp/arc-name"
            # the previous sed command sometimes causes failed match since some special chars still not escape,
            # so changed to the following line
            tmp_str=${ctx##"$TMP_DIR"}

            echo -e "==========>>>>>\n[[[FoundHere]]]";
            echo -e "$( sha1sum -b -- "$ctx" | sed 's/^\([0-9a-fA-F]\+\).*/\1/' )";
            echo -e "${INI_DIR}${tmp_str}\n<<<<<==========\n";    # wrap by considering if too long path.


            # or use this one instead.
            # echo -e "$( sha1sum -b -- "$ctx" | sed 's/^\([0-9a-fA-F]\+\).*/\1/' ) ${INI_DIR}${tmp_str}\n";


        # note, by the grep, the $2 not quoted for options injection.
        elif [ "$2" = 'cp' ] || [ "$2" = 'cq' ] || [ "$2" = 'cr' ] || ! ! grep $2 -- "$ctx"; then

            tmp_str=${ctx##"$TMP_DIR"}

            echo -e "==========>>>>>\n[[[FoundHere]]]";
            echo -e "${INI_DIR}${tmp_str}\n<<<<<==========\n";

            if [ "$3" != $'null' ]; then
                i=0;
                j=$( basename -- "$ctx" )
                k=$j
                while [ -e "${3}${k}" ] || [ -e "${3}${k}.path" ]; do
                    (( i=$i+1 ));
                    k="$j($i)"
                done

                # 1) unconditionally path file; 2) match && nonempty $3 or 'cp' will copy target file;
                # 3) 'cr' for adding checksum in path file.
                tmp_1=""
                if [ "$2" = 'cr' ]; then
                    tmp_1=$( sha1sum -b -- "$ctx" | sed 's/^\([0-9a-fA-F]\+\).*/\1\ /' )
                elif [ "$2" != 'cq' ]; then
                    cp -- "$ctx" "${3}${k}"             # copy the matched file to the target folder
                fi

                echo "${tmp_1}${INI_DIR}${tmp_str}" > "${3}${k}.path"
            fi

        else echo "=====>>>>> $ctx";

        fi

    done
else                                                    # only for file name search
    find -L ~+ -type f -regextype grep -iregex "$1" | sed 's/\(.*\)/\"\1\"/' | xargs -n1 # list all the existing pdfs
fi


t=$( find -L ~+ -type f -regextype sed -iregex '.*\.\(zip\|rar\|ace\|arj\|t\?gz\|tar\|z\|7z\|xz\|bz2\|lzh\|ex[e_]\{1\}\|iso\)' | sed 's/\(.*\)/\"\1\"/' | xargs -n1 )

IFS_OLD="$IFS"
IFS=$'\n'
for tt in $t; do

    echo "----->>>>>  $tt"

    # the following line is incorrect but is ok since it through to the end(where meant to be) and "\lfile" meant to be not found.
    # the new replacement command however weird, when use 1 instead of 0 would go wrong.
    #ttt=$( 7z -px l "$tt" | sed -n '/Date/,/\lfile/p' )
    ttt=$( 7z -px l -- "$tt" | tac | sed '0,/fi/d' | tac | sed '0,/Dat/d' )
    v=$( echo "$ttt" | grep -m1 -q -i "\.zip$\|\.rar$\|\.ace$\|\.arj$\|\.t\?gz$\|\.tar$\|\.z$\|\.7z$\|\.xz$\|\.bz2$\|\.lzh$\|\.ex[e_]\{1\}$\|\.iso$" )
    if [ $? -eq 0 ]; then                               # need to extract further for advanced search since another package inside
        IFS="$IFS_OLD"                                  # branch out then need recovery

        # note the current file is in /tmp/arc-name/path-in-arc, so we need path-in-arc string
        # however it might be in the $PWD instead, so use sed to cover both conditions
        #tmp_str=$( echo "$tt" | sed 's,'"$TMP_DIR"',,' )
        # the previous sed command sometimes causes failed match since some special chars still not escape,
        # so changed to the following line
        tmp_str=${tt##"$TMP_DIR"}

        "$SCRIPT_DIR"/"$SCRIPT_NAME" "$1" "$2" "$3" "$tt" "$SCRIPT_DIR" "$SCRIPT_NAME" "${INI_DIR}${tmp_str}"

        IFS=$'\n'                                       # branch in then need recovery
    elif [ "$2" != $'null' ]; then                      # need to extract further if at least one match for context search
        echo "$ttt" | grep -m1 -q -i "$1"
        if [ $? -eq 0 ]; then
            IFS="$IFS_OLD"

            # note the current file is in /tmp/arc-name/path-in-arc, so we need path-in-arc string
            # however it might be in the $PWD instead, so use sed to cover both conditions
            #tmp_str=$( echo "$tt" | sed 's,'"$TMP_DIR"',,' )
            # the previous sed command sometimes causes failed match since some special chars still not escape,
            # so changed to the following line
            tmp_str=${tt##"$TMP_DIR"}

            "$SCRIPT_DIR"/"$SCRIPT_NAME" "$1" "$2" "$3" "$tt" "$SCRIPT_DIR" "$SCRIPT_NAME" "${INI_DIR}${tmp_str}"

            IFS=$'\n'
	fi
    else
        echo "$ttt" | grep -i "$1"
    fi

done
IFS="$IFS_OLD"

if [ "$inipath" != "$arcpath" ]; then                   # if not the root
    cd -- "$inipath"
    rm -rf -- "$arcpath"
else
    exec 3>&-                                           # done the search and release fd3
    echo; echo $( date ); echo;
    (( time_elapsed=$SECONDS-$elapse_time_b ));
    echo -e "\nit took $(( $time_elapsed / 60 )) minute(s) $(( $time_elapsed % 60 )) seconds\n";
fi


# end of sh
