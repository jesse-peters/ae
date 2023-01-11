#!/bin/bash
dry_run=false

while getopts ":l:d:e:np:h" opt; do
    case $opt in
    l)
        license_file=${OPTARG}
        ;;
    d)
        search_dir=${OPTARG}
        ;;
    e)
        exclude_dirs=${OPTARG}
        ;;
    n)
        dry_run=true
        ;;
    p)
        pattern=${OPTARG}
        ;;
    h)
        echo "Usage: $0 -l licensefile.txt -d directory -e dir1:dir2:dir3 -n dry_run -p pattern"
        echo " -l: location of the license file"
        echo " -d: directory to search in"
        echo " -e: a list of directories to exclude in the find command, separated by colons"
        echo " -n: dry run mode, only list files that would be modified"
        echo " -p: pattern for the file matching, for example: '*.go'"
        echo " -h: display this help message"
        exit 0
        ;;
    \?)
        echo "Invalid option -$OPTARG" >&2
        exit 1
        ;;
    esac
done

last_license_line=$(tail -n 1 "$license_file")
license_hash=$(sha256sum "$license_file" | cut -d ' ' -f 1)

find "$search_dir" -name "$pattern" -path "$exclude_dirs" -prune -o -name "$pattern" -print | while read -r file; do
    target_hash=$(sha256sum "$file" | cut -d ' ' -f 1)
    if [[ "$license_hash" != "$target_hash" ]]; then
        first_line=$(head -n 1 "$file")
        if [[ "$first_line" != "$(head -n 1 "$license_file")" ]]; then
            if $dry_run; then
                echo "Would add license to ${file}"
            else
                echo "Adding license to ${file}"
                echo -e "$(<"$license_file")\n" >"$file"
            fi
        elif (grep -qF "$last_license_line" "$file"); then
            line_number=$(grep -nF "$last_license_line" "$file" | cut -d ":" -f 1)
            if [[ "$line_number" =~ ^[0-9]+$ ]]; then
                if $dry_run; then
                    echo "Would update license in ${file}"
                else
                    echo "Updating license in ${file}"
                    tail -n +$((line_number + 1)) "$file" >"${file}.tmp"
                    echo -e "$(<"$license_file")\n" >"$file"
                    cat "${file}.tmp" >>"$file"
                    rm "${file}.tmp"
                fi
            else
                echo "The ${file} cannot be parsed"
            fi
        fi
    fi
done

if $dry_run; then
    exit 1
fi
