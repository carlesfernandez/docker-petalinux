# docker-petalinux

A somehow generic Xilinx PetaLinux docker file, using Ubuntu (though some tweaks
might be possible for Windows).

It was successfully tested with version `2018.3` and `2019.1`, _which is the
last version handled by this release_.

> Inspired by
> [docker-petalinux](https://github.com/matthieu-labas/docker-petalinux),
> [docker-xilinx-petalinux-desktop](https://github.com/JamesAnthonyLow/docker-xilinx-petalinux-desktop)
> (and some of [petalinux-docker](https://github.com/xaljer/petalinux-docker)).

## Prepare installer

The PetaLinux Installer is to be downloaded from
[Xilinx website](https://www.xilinx.com/support/download/index.html/content/xilinx/en/downloadNav/embedded-design-tools.html).
It needs to be prepared for unattended installation.

Run the installer and save the `petalinux-vXXX.X-final-installer.run` file in
`./resources/`

We need to patch the Petalinux installer so it does not ask to accept licences.

> N.B. I'm not sure it's completely legal; but I haven't been able to script an
> `expect` to automatically accept them (which might not be legal as well
> anyway). So we'll consider your download means you accept those licenses
> (which are available in the petalinux install directory)

Run:

    cd resources
    ./patch_petalinux_installer.sh ./petalinux-vXXX.X-final-installer.run

(that will patch the installer _in place_).

## Build the image

Run:

    ./docker_build.sh <VERSION>

> `<VERSION>` can be `2018.3` or `2019.1`, ... Corresponding petalinux installer
> is expected to be found in a `./resources` directory.

The `docker_build.sh` will automatically spawn a simple HTTP server to serve the
installer instead of copying it to the docker images (especially pushing them to
the Docker daemon. Big space/time saver).

The image takes a long time to build (up to a couple hours, depending on disk
space and system use), but should succeed.

It weights around 15 GB.

### Parameters

Several arguments can be provided to customize the build, with `--build-arg`:

- `XILVER` for the Xilinx version to install. The `Dockerfile` expects to find
  `${HTTP_SERVER}/petalinux-v${XILVER}-final-installer.run` for the PetaLinux
  installer (unless `PETALINUX_INSTALLER` is given). <br/>Defaults to `2018.3`.

- `PETALINUX_BASE` is the name of the PetaLinux base. Petalinux will be
  installed in `/opt/${PETALINUX_BASE}` and the installer is expected to be
  sourced from `resources/${PETALINUX_BASE}-installer.run`. <br/>Defaults to
  `petalinux-v${XILVER}-final`.

- `PETALINUX_INSTALLER` is the PetaLinux installer file. <br/>Defaults to
  `${PETALINUX_BASE}-installer.run`

- `HTTP_SERV` is the HTTP server serving both SDK and PetaLinux installer.
  <br/>Defaults to `http://172.17.0.1:8000/resources`.

You can fully customize the installation by manually running e.g.:

    docker build . -t petalinux:2018.3 \
        --build-arg XILVER=2018.3 \
        --build-arg PETALINUX_INSTALLER=petalinux/petalinux-v2018.3-final-patched.run \
        --build-arg HTTP_SERV=https://local.company.com/installers

Petalinux will be retrieved at
`https://local.company.com/installers/petalinux/petalinux-v2018.3-final-patched.run`

## Work with a PetaLinux project

A helper script `petalin.sh` is provided that should be run _inside_ a petalinux
project directory. It basically is a shortcut to:

    docker run -ti -v "$PWD":"$PWD" -w "$PWD" --rm -u petalinux petalinux:<latest version> $@

When run without arguments, a shell will spawn, _with PetaLinux `settings.sh`
already sourced_, so you can directly execute `petalinux-*` commands.

    user@host:/path/to/petalinux_project$ /path/to/petalin.sh
    petalinux@a3ce6f8c:/path/to/petalinux_project$ petalinux-build

Otherwise, the arguments will be executed as a command.

If you want to use `repo`, you will need to switch to Python 3.6, and then
switch back to Python2.7 after using it:

    # sudo update-alternatives --config python

Select Python 3.6 (option number 2), and then use `repo` (`repo init ...`,
`repo sync`). When finished, switch back to Python 2.7 in order to use the
`petalinux-*` commands:

    # sudo update-alternatives --auto python
