{
  pkgs,
  inputs,
  ...
}:

{
  packages = with pkgs; [
    ansible
    wireguard-tools
    xray
    openssl
    # password ssh to the Docker test container
    sshpass
  ];
}
