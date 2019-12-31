# Etcetera

Apple platform utilities I need on almost every project but which, individually, are too small to exist on their own.

## So What

Etcetera is a mish-mash of extensions and utility classes. Every file in this repository is (mostly) intended to stand on its own, requiring nothing except some first-party Apple frameworks. Sometimes, like with `ImageCache`, that means a given file is embarassingly long, but that's a tradeoff I'm willing to make. Nothing here is meant to be a permanent solution for the lifetime of a world-class project, but rather an accelerant when setting up a new project.

## Usage

Swift Package Manager is the _de rigeur_ solution these days. Adding a Swift package to an Xcode project is absurdly easy. I don't use Cocoapods or Carthage, and I have no interest in adding support for them.

## Acknowledgements

- The `Activity` approach to the `os_activity` wrapper is based on work by [Zach Waldowski](https://gist.github.com/zwaldowski/49f61292757f86d7d036a529f2d04f0c).
