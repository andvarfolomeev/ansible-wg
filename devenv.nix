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
  ];
}
