Music Player Daemon
===================

[Music Player Daemon][1] (MPD) is a flexible, powerful, server-side application
for playing music. Through plugins and libraries it can play a variety of sound
files while being controlled by its network protocol.

:+1: [easypi/mpd-arm][2] works on Raspberry Pi very well.

NOTE: This is based on the approach used by [vimagick/mpd](https://github.com/vimagick/dockerfiles/tree/master/mpd) and should function as
a drop-in replacement, despite not sharing any code.

You can also find a [prebuilt image on Docker Hub](https://hub.docker.com/repository/docker/cybolic/mpd).


## Commands

Build the docker image locally:
```
    nix build
```

Build the custom MPD package used by the image:
```
    nix build '.#customMpd'
```

Build the custom MPD package with debug symbols:
```
    nix build '.#debugMpd'
```

If you have [direnv](https://direnv.net/) installed, you'll get a quick guide printed in your shell.
Otherwise, you can enter the development shell manually:
```
    nix develop
```

## docker-compose.yml

```yaml
services:

  mpd:
    image: cybolic/mpd
    ports:
      - "6600:6600"
      - "8800:8800"
    volumes:
      - /docker-configs/docker/mpd:/config
      # This is to have your config file as a bound mount for easier editing
      - /docker-configs/docker/mpd/mpd.conf:/etc/mpd/mpd.conf
      - /data/Music:/music
      - /data/Music/Playlists:/playlist

    # You can leave this out if running a setellite setup
    devices:
      - /dev/snd

    restart: unless-stopped

```

## Server Setup

```bash
$ mkdir -p /docker-configs/mpd/{config,music,playlists}
$ cd /docker-configs/mpd/

$ wget https://upload.wikimedia.org/wikipedia/commons/d/d5/Pop_Goes_the_Weasel.ogg -O data/music/test.ogg

$ docker-compose up -d

$ docker-compose exec mpd sh
>>> mpc help
>>> mpc update
>>> mpc ls | mpc add
>>> mpc playlist
>>> mpc repeat on
>>> mpc random on
>>> mpc
>>> mpc clear
>>> mpc lsplaylists
>>> mpc load shoutcast
>>> mpc play
>>> exit

$ docker-compose exec mpd ncmpcpp
...........
...........
... TUI ...
...........
...........
```

## Client Setup

- Android: https://play.google.com/store/apps/details?id=com.namelessdev.mpdroid
- Desktop: http://rybczak.net/ncmpcpp/

```yaml
Host: x.x.x.x
Port: 6600
Streaming host: x.x.x.x
Streaming port: 8800
```

## Read More

- <https://wiki.archlinux.org/index.php/Music_Player_Daemon>
- <https://wiki.archlinux.org/index.php/Music_Player_Daemon/Tips_and_tricks>
- <https://wiki.archlinux.org/index.php/Streaming_With_Icecast>
- <https://stmllr.net/blog/streaming-audio-with-mpd-and-icecast2-on-raspberry-pi/>
- <https://www.musicpd.org/doc/user/input_plugins.html>

[1]: https://www.musicpd.org/
[2]: https://hub.docker.com/r/easypi/mpd-arm/

