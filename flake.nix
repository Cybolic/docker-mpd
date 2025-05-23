{
  description = "Docker image for MPD Music Player Daemon";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }: let
    imageName = "mpd";
    imageTag = "latest";
    dockerHubRepo = "cybolic/${imageName}";
  in
    with flake-utils.lib; eachSystem allSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        stdenv = pkgs.stdenv;

        # Use mpd-small, but without systemd as we're just running the daemon directly
        customMpd = minimalMpd.overrideAttrs (oldAttrs: let
          version = "0.24.4";
          filterSystemd = inputs: builtins.filter 
            (input: (input.pname or input.name or "") != "systemd") 
            inputs;
        in {
          inherit version;
          src = pkgs.fetchFromGitHub {
            owner = "MusicPlayerDaemon";
            repo = "MPD";
            rev = "v${version}";
            sha256 = "sha256-wiQa6YtaD9/BZsC9trEIZyLcIs72kzuP99O4QVP15nQ=";
          };

          mesonFlags = builtins.filter 
            (flag: !(
              builtins.match ".*systemd.*" flag != null
              || builtins.match ".*test=true.*" flag != null
              || builtins.match ".*manpages.*" flag != null
              || builtins.match ".*html_manual.*" flag != null
            )) 
            (oldAttrs.mesonFlags or []);

          buildInputs = filterSystemd (oldAttrs.buildInputs or []);
          nativeBuildInputs = filterSystemd (oldAttrs.nativeBuildInputs or []);
        });
        debugMpd = customMpd.overrideAttrs (oldAttrs: {
          pname = "${oldAttrs.pname}-debug";
          mesonFlags = oldAttrs.mesonFlags or [] ++ [
              "--buildtype=debug"
              "-Db_ndebug=false"
          ];
          CXXFlags = oldAttrs.CXXFlags or [] ++ [
            "-ggdb" "-Og"
          ];
          dontStrip = true;
        });

        minimalMpd = pkgs.mpdWithFeatures {
          features =
            [
              "qobuz"
              "shout"
              "webdav"
              "nfs"
              "curl"
              "mms"
              "bzip2"
              "zzip"
              "audiofile"
              "faad"
              "flac"
              "gme"
              "mpg123"
              "opus"
              "vorbis"
              "vorbisenc"
              "lame"
              "libsamplerate"
              "libmpdclient"
              "id3tag"
              "expat"
              "pcre"
              "sqlite"
            ]
            ++ lib.optionals stdenv.hostPlatform.isLinux [
              "io_uring"
            ];
        };

        dockerImage = pkgs.dockerTools.buildImage {
          name = "mpd";
          created = "now";
          tag = "latest";

          config = {
            Cmd = [
              "${customMpd}/bin/mpd" "--stderr" "--no-daemon" "/etc/mpd/mpd.conf"
            ];
            Env = [
              "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            ];
            ExposedPorts = {
              "6600/tcp" = {};
            };
            Volumes = {
              "/var/lib/mpd" = {};
            };
          };

          runAsRoot = ''
            ${pkgs.dockerTools.shadowSetup}
            mkdir -p /root
            mkdir -p etc/ssl/certs
            ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
          '';

          extraCommands = ''
            mkdir -p var/lib/mpd
            mkdir -p etc/mpd
            cat > etc/mpd/mpd.conf << 'EOF'
            music_directory     "/var/lib/mpd/music"
            playlist_directory  "/var/lib/mpd/playlists"
            db_file             "/var/lib/mpd/database"
            pid_file            "/var/lib/mpd/pid"
            state_file          "/var/lib/mpd/state"
            sticker_file        "/var/lib/mpd/sticker.sql"
            bind_to_address     "0.0.0.0"
            port                "6600"
            EOF
          '';
        };

        pushScript = pkgs.writeShellScriptBin "push-to-dockerhub" ''
          set -e
          echo "Building image..."
          nix build '.#dockerImage'

          echo "Loading image into Docker..."
          ${lib.getExe pkgs.docker} load < ./result

          echo "Tagging image for Docker Hub..."
          ${lib.getExe pkgs.docker} tag ${imageName}:${imageTag} ${dockerHubRepo}:${imageTag}

          echo "Pushing to Docker Hub..."
          ${lib.getExe pkgs.docker} push ${dockerHubRepo}:${imageTag}

          echo "Done!"
        '';

        inspectScript = pkgs.writeShellScriptBin "docker-dive" ''
          set -e
          ${lib.getExe pkgs.dive} ${imageName}:${imageTag}
        '';

      in {

        packages = {
          dockerImage = dockerImage;
          customMpd = customMpd;
          debugMpd = debugMpd;
          default = dockerImage;
        };

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              customMpd
              pushScript
              inspectScript
            ];
            shellHook = ''
              echo "MPD Docker Image Development Shell"
              echo ""
              echo "Available commands:"
              echo "  nix build                - Build the Docker image"
              echo "  nix build '.#customMpd'  - Build the minimal MPD package"
              echo "  nix build '.#debugMpd'   - Build the minimal MPD package with debug symbols"
              echo "  docker load < result     - Load the image into Docker"
              echo "  push-to-dockerhub        - Build, Tag and Push image to Docker Hub"
              echo ""
              echo "Before pushing, make sure you're logged in to Docker Hub:"
              echo "  docker login"
              echo ""
              echo "To customize the Docker Hub repository, edit the 'dockerHubRepo'"
              echo "variable in the flake.nix file."
            '';
          };
        };

      }
    );
}
