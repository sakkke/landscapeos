# LandscapeOS

![landscapeos](https://socialify.git.ci/sakkke/landscapeos/image?description=1&descriptionEditable=Like%20a%20Landscape%2C%20Unobtrusive%20OS&font=Inter&forks=1&issues=1&name=1&owner=1&pattern=Solid&pulls=1&stargazers=1&theme=Auto)

[Changelog](./CHANGELOG.md)

Like a Landscape, Unobtrusive OS.

## Build

```sh
./build.sh
```

### Requirements

**OS**

- Debian-based Linux distribution

**Commands**

- `mmdebstrap`
- `rsync`
- `arch-chroot`
- `mksquashfs`
- `mkfs.fat`
- `xorriso`
- `sudo` (optional)

#### Requirements Installation

```sh
sudo apt -y install mmdebstrap rsync arch-install-scripts squashfs-tools \
  dosfstools xorriso sudo
```

## License

[MIT](./LICENSE)
