# Homeforwarder

Simple service to expose your homelab services to the internet using SSH tunnels.
<div align="center">
  

https://github.com/user-attachments/assets/92c276bd-a600-4be3-8c53-32f9167b8c3e


</div>

## Prerequisites

To use Homeforwarder at its current state, you need to have the following completed:
- Setup SSH so that connections are key-based ([guide][ssh-key-link]).
- Setup your SSH config file to include the necessary information for the servers you want to forward to ([guide][ssh-config-link]).

Things that may be nice to have:
- Hostnames for the servers you want to forward to updated in your [hosts file][hosts-file-link].

## Building

Pre-built binaries are not provided at this time (coming in the future though). To build Homeforwarder, you need to have [Zig][zig-link] installed.
This was built on Zig 0.14.0-dev but 0.13.0+ should work as well.
Once you have Zig installed, you can clone the repository using `git clone <repo>` and then running the build script located in the scripts folder and passing in the desired architecture. 
Currently only `arm64` and `amd64` are supported.

```sh
./scripts/build.sh arm64 # Build for arm64 such as Raspberry Pi
./scripts/build.sh amd64 # Build for x86_64
```
This will create a debian package in the debs folder, for example `homeforwarder_0.0.1_amd64.deb`.
If you need to copy the package to another machine, you can use `scp` to copy it over.
```sh
scp debs/homeforwarder_0.0.1_amd64.deb user@remote:/path/to/destination
```

## Installation

Navigate to the folder containing the package and run the following command to install the package.
```sh
sudo apt install ./<package-name>.deb # For example sudo apt install ./homeforwarder_0.0.1_amd64.deb
```

After installation, you will need to setup your config file. See the [Config File](#config-file) section for more information.

## Config File

See the [config file example](config.example.json) for an reference on how to setup the config file.
The config file should be moved to /opt/homeforwarder (or you can update the empty config file located in that directory).
To understand the fields in the config file, see the following descriptions:
- `timeout`: The timeout for the SSH tunnel in seconds.
- `services`: An array of services that you want to forward.
  - `name`: The name of the service. This is used to identify the service in logs.
  - `hostname`: Hostname of service host system. If you have the hostname in your hosts file, you can use that. Otherwise, you can use the IP address.
  - `connect_port`: Port of service running on host system 
  - `forward_port`: Port of service to forward to forwarded system
  - `protocol`: Protocol of service - TCP(0) or UNIX(1). Currently only TCP is supported.
- `forward_host`: Hostname of the system you want to forward to. This is the system that the service will be forwarded to and should be the name that is setup in your SSH config file.

## Running

To start the service, you can use the following command:
```sh
sudo systemctl start homeforwarder
```

If you want to enable the service to start on boot, you can use the following command to enable and start the service:
```sh
sudo systemctl enable homeforwarder --now
```

To verify that the service is running, you can use the following command:
```sh
sudo systemctl status homeforwarder
```

If there are any issues, you can check the logs using the following command:
```sh
sudo journalctl -u homeforwarder
```

## Credits

This project was inspired by a video from [Hoff][hoff-video-link] ([GitHub][hoff-github-link]). The video is a great watch and I highly recommend it.

[ssh-key-link]: https://www.digitalocean.com/community/tutorials/how-to-configure-ssh-key-based-authentication-on-a-linux-server
[ssh-config-link]: https://linuxize.com/post/using-the-ssh-config-file
[hosts-file-link]: https://linuxhandbook.com/etc-hosts-file
[zig-link]: https://ziglang.org
[hoff-video-link]:  https://www.youtube.com/watch?v=aUBeJyfg9GQ
[hoff-github-link]: https://github.com/hoff-dot-world
