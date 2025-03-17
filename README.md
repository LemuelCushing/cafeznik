# Cafeznik

_Not a fez-wearing cat in a track suit._

There are [many](https://github.com/Dicklesworthstone/your-source-to-prompt.html?tab=readme-ov-file) code2prompt tools around, but this one is mine 🪖

## What is this?

Cafeznik is an interactive CLI (levereging the beautiful [fzf](https://github.com/junegunn/fzf)) to ease the selection and copying of code files - local or remote (GitHub) - to your clipboard. 

Why? You know why -  so I can feed it into LLMs like the lazy, lazy ~~script kiddie~~ *vibe programmer* I am. It’s streamlined, efficient, and dangerously habit-forming.


## Installation

Install it directly via RubyGems (requires Ruby 3.3 and the other dependencies [listed below](#dependencies)):

```bash
gem install cafeznik
```

## Then what?

```bash
cafeznik # or cafeznik --repo owner/repo
```

 use <kbd>tab</kbd> to select multiple files, <kbd>enter</kbd> to copy them to your clipboard, and <kbd>ctrl-c</kbd>/<kbd>esc</kbd> to exit. Selecting a directory will copy all files within it, and selecting `./` will copy everything in sight (respecting your `--exclude`s and `--grep`s ).

# looksee
Local mode:
[![asciicast](reference/local-asciinema.gif)](https://asciinema.org/a/YWcuK13nRybD234R5nkW8J7Hh)
Or remote with grep and exclude:
[![asciicast](reference/remote-asciinema.gif)](https://asciinema.org/a/fcW1ZbWsxFajk7gH6r9ttTjLJ)

## Dependencies

Cafeznik relies on a few external tools to work its magic:

- [`fzf`](https://github.com/junegunn/fzf) – Essential for interactive file selection (absolutely required)
- [`fd`](https://github.com/sharkdp/fd) – Powers local file discovery (required for local mode)
- [`ripgrep`](https://github.com/BurntSushi/ripgrep) – Enables efficient grep functionality (required when using `--grep`)
- [`bat`](https://github.com/sharkdp/bat) (& `tree`) – Provide pretty previews (optional but highly recommended)
- [`gh`](https://cli.github.com/) – Simplifies GitHub authentication (optional; you can alternatively set the GITHUB_TOKEN environment variable)

A homebrew line to install all the dependencies on macOS:

```bash
brew install fzf fd ripgrep bat tree gh
```

## Usage

### Local mode

Quickly select and copy files from your current directory:

```bash
cafeznik
```

Filter your selection to include only files that contain specific text:

```bash
cafeznik --grep "def initialize"
```

Easily exclude unwanted files or directories:

```bash
cafeznik --exclude "*.log" --exclude "tmp/"
```

### GitHub mode

Fetch and copy code directly from any GitHub repository:

```bash
cafeznik --repo owner/repo
```

It also supports full URLs:

```bash
cafeznik --repo https://github.com/owner/repo
```

## Noteworthy Flags

```
--repo, -r        Specify a GitHub repository to fetch files from 
--grep, -g        Only select files containing specific text patterns (works locally and remotely)
--exclude, -e     Exclude files or directories matching provided patterns (also works locally and remotely)
--with-tree, -t   Include a detailed file tree structure in your output (Guess what? Works locally and remotely)
```

## Less important flags
```
--no-header       Omit file headers from the copied content for a cleaner paste
--verbose         Activate detailed logging output for debugging and transparency
```

Or, you know:

```bash
cafeznik --help
```

## What's a-comin

- History of copied files - so you can easily re-copy them. Rinse, repeat.
- Optional minification of copied files
- Binary files support for multi-modal models? Might be a stretch
- Token counting. Everyone loves token counting.

## Noteworthy Competitors I did not take inspiration from

- [gitingest](https://github.com/davidesantangelo/gitingest) -  Fellow Ruby that works much better on bigger repos, and packs it all nicely in a prompt file
- [onefilellm](https://github.com/jimmc414/onefilellm) - Does so much more, expect it's a completely different thing
- [your-source-to-prompt.html](https://github.com/Dicklesworthstone/your-source-to-prompt.html) - If you wanna leave your console for a browser, you'll get plenty of nice features for your code2prompt needs
  
## License

Cafeznik is open-source software, licensed under the MIT License.

## Contributing

Please!  Feel free, this over-engineered tool welcomes all interested parties and fiestas.

Enjoy your freshly copied code! 🍪
