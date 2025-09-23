{ pkgs, lib, ... }:

pkgs.buildGoModule rec {
  pname = "payments-cli";
  version = "1.0.0";

  src = ./.;

  vendorHash = null;

  meta = with lib; {
    description = "Payment tracker widget for Waybar";
    license = licenses.mit;
  };
}
