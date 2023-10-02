# seeV

seeV is a macOS command line wrapper around the [Apple Vision framework](https://developer.apple.com/documentation/vision). Its goal is to unlock the functionality of the framework for use in shell scripts and other command line tools. seeV is written in Swift and works on macOS 10.14 and later.

Because Vision.framework ships on macOS, seeV does not require any additional dependencies or network access. It is a single executable that can be copied to any location on your system.

Currently seeV supports subject extraction (i.e. background removal). On a 2020 M1 MacBook Air subject extraction completes in under one second. More features will be added in the future.

## Installation

### Release

You can download the latest M1 build from the [Releases]( https://github.com/Nexuist/seeV/releases) page.

### Build from Source

```bash
swift build --configuration release
cp -f .build/release/seev /usr/local/bin/seev
```

## Usage

```bash
$ seev input.jpg
```

Extracts the subject from `input.jpg` and writes the result to `output.png`.

```bash
$ seev input.jpg -o foreground.png
```

Extracts the subject from `input.jpg` and writes the result to `foreground.png`.

## Next Steps

* Determine which Vision.framework features to support next (face detection, OCR, etc)
* Add a flag to determine if the output should keep the input dimensions or crop them to the subject's extent

## License

```text
MIT License

Copyright (c) 2023 Andi Andreas

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```