package main

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

// format lists are embedded at compile time instead of being read at runtime
FORMATS_IMAGES :: #load("formats/formats_images.txt", string)
FORMATS_VIDEOS :: #load("formats/formats_videos.txt", string)

USAGE :: `usage: media <command> <directory>

commands:
  convert-images-magick   convert images to avif with imagemagick
  convert-images-ffmpeg   convert images to avif with ffmpeg and libsvtav1
  convert-videos-ffmpeg   convert videos to mkv with ffmpeg and libsvtav1
  flatten                 copy all media files into <directory>_flattened
  remove-empty-dirs       remove directories without files in their subtree
  list                    show file totals, media counts, extensions, and empty directories

underscores work in command names too, e.g. convert_images_magick`

main :: proc() {
	args := os.args
	if len(args) < 2 {
		fmt.eprintln(USAGE)
		os.exit(2)
	}

	command := args[1]
	if command == "-h" || command == "--help" || command == "help" {
		fmt.println(USAGE)
		return
	}

	if len(args) < 3 {
		fmt.eprintfln("media: missing directory argument for %q", command)
		os.exit(2)
	}

	normalized, _ := strings.replace_all(command, "_", "-")
	input_directory := normalize_root(args[2])

	if !dispatch(normalized, input_directory) {
		os.exit(1)
	}
}

dispatch :: proc(command, input_directory: string) -> bool {
	switch command {
	case "convert-images-magick":
		return convert_images_magick(input_directory)
	case "convert-images-ffmpeg":
		return convert_images_ffmpeg(input_directory)
	case "convert-videos-ffmpeg":
		return convert_videos_ffmpeg(input_directory)
	case "flatten":
		return flatten_media_files(input_directory)
	case "remove-empty-dirs":
		return remove_empty_dirs(input_directory)
	case "list":
		return list_files(input_directory)
	}

	fmt.eprintfln("media: unknown command %q", command)
	fmt.eprintln(USAGE)
	return false
}

// trims trailing separators and a leading "./" or ".\" like the scripts did
normalize_root :: proc(input: string) -> string {
	root := strings.trim_right(input, `\/`)
	for strings.has_prefix(root, "./") || strings.has_prefix(root, ".\\") {
		root = root[2:]
	}
	if root == "" {
		return "."
	}
	return root
}

// joins two path fragments with the platform separator
join_path :: proc(base, name: string) -> string {
	return fmt.aprintf("%s%c%s", base, os.Path_Separator, name)
}

// parses a newline separated extension list, lowercased and without dots
parse_formats :: proc(source: string) -> []string {
	formats := make([dynamic]string)

	lines, _ := strings.split_lines(source)
	for line in lines {
		format := strings.trim_left(strings.trim_space(line), ".")
		if format == "" {
			continue
		}

		lower, _ := strings.to_lower(format)
		append(&formats, lower)
	}

	return formats[:]
}

// images and videos combined, as used by flatten and list
all_formats :: proc() -> []string {
	formats := make([dynamic]string, 0, 32)
	append(&formats, ..parse_formats(FORMATS_IMAGES))
	append(&formats, ..parse_formats(FORMATS_VIDEOS))
	return formats[:]
}

// lowercase extension without the leading dot, e.g. img.jpg becomes jpg
extension_of :: proc(path: string) -> string {
	extension := filepath.ext(path)
	for len(extension) > 0 && extension[0] == '.' {
		extension = extension[1:]
	}

	lower, _ := strings.to_lower(extension)
	return lower
}

// replaces the extension of a path, the new extension includes the dot
replace_extension :: proc(path, extension: string) -> string {
	current := filepath.ext(path)
	return fmt.aprintf("%s%s", path[:len(path) - len(current)], extension)
}

format_includes :: proc(formats: []string, extension: string) -> bool {
	for format in formats {
		if format == extension {
			return true
		}
	}
	return false
}

path_exists :: proc(path: string) -> bool {
	info, err := os.stat(path, context.allocator)
	if err != nil {
		return false
	}

	os.file_info_delete(info, context.allocator)
	return true
}

ascii_to_lower :: proc(char: byte) -> byte {
	if char >= 'A' && char <= 'Z' {
		return char + ('a' - 'A')
	}
	return char
}

// compares two strings without regard to ascii case
compare_ignore_case :: proc(a, b: string) -> int {
	common := min(len(a), len(b))
	for index in 0 ..< common {
		a_char := ascii_to_lower(a[index])
		b_char := ascii_to_lower(b[index])
		if a_char != b_char {
			return int(a_char) - int(b_char)
		}
	}
	return len(a) - len(b)
}

// formats a percentage like powershell does, dropping a trailing .0
format_percent :: proc(buffer: []byte, value: f64) -> string {
	text := fmt.bprintf(buffer, "%.1f", value)
	if strings.has_suffix(text, ".0") {
		return text[:len(text) - 2]
	}
	return text
}

// recursively collects files, filtered by extension when formats is not empty
collect_files :: proc(root: string, formats: []string = nil) -> []string {
	files := make([dynamic]string)
	walk_files(root, formats, &files)
	return files[:]
}

// walks a directory depth first, the way get-childitem -recurse does
walk_files :: proc(directory: string, formats: []string, files: ^[dynamic]string) {
	entries, err := os.read_all_directory_by_path(directory, context.allocator)
	if err != nil {
		fmt.eprintfln("media: failed to read %s: %v", directory, err)
		return
	}
	defer os.file_info_slice_delete(entries, context.allocator)

	slice.sort_by(entries, proc(a, b: os.File_Info) -> bool {
		return compare_ignore_case(a.name, b.name) < 0
	})

	for entry in entries {
		if entry.type == .Directory {
			continue
		}

		if len(formats) > 0 && !format_includes(formats, extension_of(entry.fullpath)) {
			continue
		}

		append(files, strings.clone(entry.fullpath))
	}

	// files of a directory come before the files of its subdirectories
	for entry in entries {
		if entry.type == .Directory {
			walk_files(entry.fullpath, formats, files)
		}
	}
}

// returns directories without files in their subtree, in walk order
find_empty_dirs :: proc(input_directory: string) -> []string {
	directories := make([dynamic]string)
	direct_file_count := make(map[string]int)

	walk_directories(input_directory, &directories, &direct_file_count)

	has_files := make(map[string]bool)
	// parents come before children, so walking backwards settles children first
	for index := len(directories) - 1; index >= 0; index -= 1 {
		directory := directories[index]
		if direct_file_count[directory] > 0 || has_files[directory] {
			has_files[directory] = true
			has_files[filepath.dir(directory)] = true
		}
	}

	empty_dirs := make([dynamic]string, 0, len(directories))
	for directory in directories {
		if !has_files[directory] {
			append(&empty_dirs, directory)
		}
	}

	return empty_dirs[:]
}

// walks a directory level by level and records directories and their file counts
walk_directories :: proc(directory: string, directories: ^[dynamic]string, file_counts: ^map[string]int) {
	queue := make([dynamic]string, 0, 16)
	append(&queue, strings.clone(directory))

	// get-childitem -directory -recurse lists a whole level before the next one
	for index := 0; index < len(queue); index += 1 {
		current := queue[index]
		entries, err := os.read_all_directory_by_path(current, context.allocator)
		if err != nil {
			fmt.eprintfln("media: failed to read %s: %v", current, err)
			continue
		}

		slice.sort_by(entries, proc(a, b: os.File_Info) -> bool {
			return compare_ignore_case(a.name, b.name) < 0
		})

		for entry in entries {
			if entry.type == .Directory {
				append(directories, strings.clone(entry.fullpath))
				append(&queue, strings.clone(entry.fullpath))
				continue
			}

			if count, exists := file_counts[current]; exists {
				file_counts[current] = count + 1
			} else {
				file_counts[strings.clone(current)] = 1
			}
		}

		os.file_info_slice_delete(entries, context.allocator)
	}
}

// converts one input file into one output file
Command :: proc(input_path, output_path: string) -> bool

// common logic for file conversion
convert_media :: proc(
	input_formats: string,
	output_format: string,
	identifier: string,
	command: Command,
	input_directory: string,
) -> bool {
	formats := parse_formats(input_formats)
	files := collect_files(input_directory, formats)
	total := len(files)

	// the walker reports absolute paths, so relative paths are trimmed from it
	absolute_input, _ := os.get_absolute_path(input_directory, context.allocator)

	output_root := fmt.aprintf("%s_%s_%s", input_directory, output_format, identifier)
	defer delete(output_root)

	output_extension := fmt.aprintf(".%s", output_format)
	defer delete(output_extension)

	failed := 0

	for input_file, index in files {
		percent_buffer: [32]byte
		percent := format_percent(percent_buffer[:], f64(index + 1) / f64(total) * 100)

		relative := strings.trim_left(strings.trim_prefix(input_file, absolute_input), `\/`)
		output_file := replace_extension(join_path(output_root, relative), output_extension)

		output_directory := filepath.dir(output_file)
		if !path_exists(output_directory) {
			if err := os.make_directory_all(output_directory); err != nil {
				fmt.eprintfln("media: failed to create %s: %v", output_directory, err)
				delete(output_file)
				failed += 1
				continue
			}
		}

		if path_exists(output_file) {
			fmt.printfln("Skipping existing file: %s", output_file)
			delete(output_file)
			continue
		}

		fmt.printfln(
			"[%d/%d] [%s%%] [%s] Converting %s to %s",
			index + 1, total, percent, identifier,
			filepath.base(input_file), filepath.base(output_file),
		)

		if !command(input_file, output_file) {
			failed += 1
		}

		delete(output_file)
	}

	fmt.printfln("Finished converting media")
	return failed == 0
}

// runs a tool with the console handles inherited so it can print its own errors
run_command :: proc(arguments: []string) -> bool {
	process, err := os.process_start(os.Process_Desc{
		command = arguments,
		stdin   = os.stdin,
		stdout  = os.stdout,
		stderr  = os.stderr,
	})
	if err != nil {
		fmt.eprintfln("media: failed to run %s: %v", arguments[0], err)
		return false
	}

	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("media: failed to wait for %s: %v", arguments[0], wait_err)
		return false
	}
	if !state.success {
		fmt.eprintfln("media: %s exited with code %d", arguments[0], state.exit_code)
		return false
	}

	return true
}

// convert images to avif with imagemagick
convert_images_magick :: proc(input_directory: string) -> bool {
	return convert_media(FORMATS_IMAGES, "avif", "magick", magick_command, input_directory)
}

magick_command :: proc(input_path, output_path: string) -> bool {
	return run_command([]string{"magick", input_path, output_path})
}

// convert images to avif with ffmpeg and libsvtav1
convert_images_ffmpeg :: proc(input_directory: string) -> bool {
	return convert_media(FORMATS_IMAGES, "avif", "libsvtav1", ffmpeg_image_command, input_directory)
}

ffmpeg_image_command :: proc(input_path, output_path: string) -> bool {
	os.set_env("SVT_LOG", "1")
	return run_command([]string{
		"ffmpeg", "-hide_banner", "-loglevel", "error",
		"-i", input_path,
		"-c:v", "libsvtav1", "-preset", "8", "-crf", "26",
		output_path,
	})
}

// convert videos to mkv with ffmpeg and libsvtav1
convert_videos_ffmpeg :: proc(input_directory: string) -> bool {
	return convert_media(FORMATS_VIDEOS, "mkv", "libsvtav1", ffmpeg_video_command, input_directory)
}

ffmpeg_video_command :: proc(input_path, output_path: string) -> bool {
	return run_command([]string{
		"ffmpeg", "-hide_banner", "-loglevel", "error",
		"-i", input_path,
		"-c:v", "libsvtav1", "-preset", "8", "-crf", "26",
		"-c:a", "aac", "-b:a", "320k",
		output_path,
	})
}

// copy all media files into a flat directory next to the input directory
flatten_media_files :: proc(input_directory: string) -> bool {
	flat_directory := fmt.aprintf("%s_flattened", input_directory)
	defer delete(flat_directory)

	if !path_exists(flat_directory) {
		if err := os.make_directory(flat_directory); err != nil {
			fmt.eprintfln("media: failed to create %s: %v", flat_directory, err)
			return false
		}
	}

	// the scripts printed the root with its "./" prefix
	if filepath.is_abs(input_directory) {
		fmt.printfln("Flattening folder: %s", input_directory)
	} else {
		fmt.printfln("Flattening folder: ./%s", input_directory)
	}

	files := collect_files(input_directory, all_formats())
	total := len(files)

	for file, index in files {
		percent_buffer: [32]byte
		percent := format_percent(percent_buffer[:], f64(index + 1) / f64(total) * 100)
		fmt.printfln("[%d/%d] [%s%%] %s", index + 1, total, percent, filepath.base(file))

		destination := unique_destination(flat_directory, filepath.base(file))
		if err := os.copy_file(destination, file); err != nil {
			fmt.eprintfln("media: failed to copy %s: %v", file, err)
		}
		delete(destination)
	}

	fmt.printfln("Flattening complete!")
	return true
}

// adds a counter to the name when the destination already exists
unique_destination :: proc(flat_directory, name: string) -> string {
	destination := join_path(flat_directory, name)

	counter := 1
	for path_exists(destination) {
		extension := filepath.ext(name)
		stem := strings.trim_suffix(name, extension)

		delete(destination)
		destination = join_path(flat_directory, fmt.tprintf("%s_%d%s", stem, counter, extension))
		counter += 1
	}

	return destination
}

// remove directories without files in their subtree
remove_empty_dirs :: proc(input_directory: string) -> bool {
	empty_dirs := find_empty_dirs(input_directory)

	failed := 0
	// deepest first, so a parent is only removed after its children
	for index := len(empty_dirs) - 1; index >= 0; index -= 1 {
		directory := empty_dirs[index]
		// a parent may already be gone together with its children
		if !path_exists(directory) {
			continue
		}

		if err := os.remove_all(directory); err != nil {
			fmt.eprintfln("media: failed to remove %s: %v", directory, err)
			failed += 1
		}
	}

	return failed == 0
}

// list file totals, media counts by extension, file extensions, and empty directories
list_files :: proc(input_directory: string) -> bool {
	files := collect_files(input_directory)

	media_formats := all_formats()
	counts := make(map[string]int)
	media_count := 0
	types := make([dynamic]string)
	for file in files {
		extension := extension_of(file)

		if format_includes(media_formats, extension) {
			media_count += 1
			if count, exists := counts[extension]; exists {
				counts[extension] = count + 1
			} else {
				counts[strings.clone(extension)] = 1
			}
		}
		delete(extension)

		file_extension := filepath.ext(file)
		if !contains_ignore_case(types[:], file_extension) {
			append(&types, strings.clone(file_extension))
		}
	}

	Extension_Count :: struct {
		extension: string,
		count:     int,
	}
	results := make([dynamic]Extension_Count, 0, len(counts))
	for extension, count in counts {
		append(&results, Extension_Count{extension, count})
	}

	slice.sort_by(results[:], proc(a, b: Extension_Count) -> bool {
		if a.count != b.count {
			return a.count > b.count
		}
		return a.extension < b.extension
	})

	fmt.printfln("Total files: %d", len(files))
	fmt.println()
	fmt.printfln("  %-10s %8s", "Extension", "Count")
	fmt.printfln("  %-10s %8s", "----------", "-----")

	slice.sort_by(types[:], proc(a, b: string) -> bool {
		return compare_ignore_case(a, b) < 0
	})

	for extension in types {
		fmt.printfln("  %s", extension)
	}

	fmt.println()
	fmt.printfln("Media files: %d", media_count)
	fmt.println()
	fmt.printfln("  %-10s %8s", "Extension", "Count")
	fmt.printfln("  %-10s %8s", "----------", "-----")
	for result in results {
		count := fmt.tprintf("%d", result.count)
		fmt.printfln("  %-10s %8s", result.extension, count)
	}

	empty_dirs := find_empty_dirs(input_directory)
	fmt.println()
	fmt.printfln("Empty directories: %d", len(empty_dirs))
	for directory in empty_dirs {
		fmt.printfln("  %s", directory)
	}

	return true
}

contains_ignore_case :: proc(values: []string, value: string) -> bool {
	for candidate in values {
		if compare_ignore_case(candidate, value) == 0 {
			return true
		}
	}
	return false
}

