# Etcetera

Apple platform utilities I need on almost every project but which, individually, are too small to exist on their own.

## What This Isn't

**Etcetera is not a framework**. Every file in this repository is intended to stand on its own, requiring nothing except some first-party Apple frameworks. Sometimes, like with `ImageCache`, that means a given file is embarassingly long, but that's a tradeoff I'm willing to make. None of these things are meant to be permanent solutions for the lifetime of a world-class project, but rather up-front accelerants to save time when setting up a new project.

## Usage

You're on your own with dependency management. I don't use Cocoapods or Carthage, so I don't feel like adding support for them here. A git submodule is sufficient and universally applicable:

```
git submodule add git@github.com:/jaredsinclair/etcetera.git
```

Then add only those source files that you wish to use to whatever targets are most applicable.
