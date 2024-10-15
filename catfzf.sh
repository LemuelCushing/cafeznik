#! /bin/bash

# Original bash catfzf for reference
catp() {
	if [[ "$1" == "-h" ]]; then
		echo "Usage: catp [--no-header|-nh] <files>"
		echo "Concatenate and copy the contents of specified files to the clipboard."
		echo "  --no-header, -nh    Use cat instead of tail -n +1"
		return
	fi

	local use_cat=false

	# Check for the --no-header or -nh flag
	for arg in "$@"; do
		if [[ "$arg" == "--no-header" || "$arg" == "-nh" ]]; then
			use_cat=true
			break
		fi
	done

	# Remove the flag from the arguments list
	local files=("${@/--no-header/}")
	files=("${files[@]/-nh/}")

	# Concatenate and copy to clipboard using cat or tail -n +1
	if [[ "$use_cat" == true ]]; then
		cat "${files[@]}" | pbcopy
	else
		tail -n +1 "${files[@]}" | pbcopy
	fi
}

catfzf() {
	if [[ "$1" == "-h" ]]; then
		echo "Usage: catfzf [--no-header|-nh] [--only-dirs|-d] [--ignore <file1> [<file2> ...]] [--changed|-c] [--with-diff|-wd]"
		echo "Select files using fzf and copy their contents to the clipboard."
		echo "  --no-header, -nh    Use cat instead of tail -n +1"
		echo "  --only-dirs, -d     Limit fzf selection to only directories"
		echo "  --ignore            Specify files to ignore (can be used multiple times)"
		echo "  --changed, -c       Only show files with local changes compared to main"
		echo "  --with-diff, -wd    Include the diff in the copied content (implies --changed)"
		return
	fi

	local use_cat=false
	local only_dirs=false
	local ignore_files=()
	local only_changed=false
	local with_diff=false

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case $1 in
		--no-header | -nh)
			use_cat=true
			shift
			;;
		--only-dirs | -d)
			only_dirs=true
			shift
			;;
		--ignore)
			shift
			while [[ $# -gt 0 && ! $1 =~ ^-- ]]; do
				ignore_files+=("$1")
				shift
			done
			;;
		--changed | -c)
			only_changed=true
			shift
			;;
		--with-diff | -wd)
			with_diff=true
			only_changed=true
			shift
			;;
		*)
			echo "Unknown option: $1"
			return 1
			;;
		esac
	done

	# Construct the fd command with ignore options
	local fd_cmd="echo ./; fd . --follow --hidden --exclude .git"
	for ignore in "${ignore_files[@]}"; do
		fd_cmd+=" --exclude '$ignore'"
	done

	# Use git diff to get changed files if needed
	local git_cmd=""
	if [[ "$only_changed" == true ]]; then
		git_cmd="git diff --name-only main"
	fi

	# Use fzf to select files or directories
	local selected
	if [[ "$only_dirs" == true ]]; then
		selected=$(eval "$fd_cmd --type dir" | fzf --multi --preview 'tree -C {} | head -n 50' --preview-window=right:60% --bind "enter:accept")
	elif [[ "$only_changed" == true ]]; then
		selected=$(eval "$git_cmd" | fzf --multi --preview '[[ -d {} ]] && tree -C {} | head -n 50 || bat --style=numbers --color=always --theme="Monokai Extended Light" {}' --preview-window=right:60% --bind "enter:accept")
	else
		selected=$(eval "$fd_cmd" | fzf --multi --preview '[[ -d {} ]] && tree -C {} | head -n 50 || bat --style=numbers --color=always --theme="Monokai Extended Light" {}' --preview-window=right:60% --bind "enter:accept")
	fi

	echo "selected: $selected"

	if [[ -n $selected ]]; then
		local files=()
		while IFS= read -r item; do
			if [[ -d "$item" ]]; then
				while IFS= read -r file; do
					# Check if the file should be ignored
					local ignore_file=false
					for ignore in "${ignore_files[@]}"; do
						if [[ "$(basename "$file")" == "$ignore" ]]; then
							ignore_file=true
							break
						fi
					done
					if [[ "$ignore_file" == false ]]; then
						files+=("$file")
					fi
				done < <(eval "$fd_cmd --type f" "$item")
			else
				files+=("$item")
			fi
		done <<<"$selected"

		local cmd
		local quoted_files=()

		for file in "${files[@]}"; do
			if [[ $file =~ [[:space:]\'\"\\] || $file == *\[*\]* ]]; then
				quoted_files+=("\"$file\"")
			else
				quoted_files+=("$file")
			fi
		done

		if [[ "$with_diff" == true ]]; then
			cmd="("
			if [[ "$use_cat" == true ]]; then
				cmd+="cat ${quoted_files[*]}; "
			else
				cmd+="tail -n +1 ${quoted_files[*]}; "
			fi
			cmd+="echo '

--- BEGIN DIFF ---'; "
			cmd+="git diff main -- ${quoted_files[*]}; "
			cmd+="echo '--- END DIFF ---'"
			cmd+=") | pbcopy"
		elif [[ "$use_cat" == true ]]; then
			cmd="cat ${quoted_files[*]} | pbcopy"
		else
			cmd="tail -n +1 ${quoted_files[*]} | pbcopy"
		fi

		eval "$cmd"

		# Add the command to the history
		THRESHOLD=1000
		if [[ "${#cmd}" -lt $THRESHOLD ]]; then
			print -s "# catfzf: \n$cmd"
		else
			echo "Command was not added to the history because it's longer than $THRESHOLD characters"
		fi

		# Count the number of files and lines
		local file_count=${#files[@]}
		local line_count
		line_count=$(pbpaste | wc -l | tr -d ' ')

		echo "Copied $file_count file(s) with a total of $line_count line(s) to the clipboard."
	fi
}
