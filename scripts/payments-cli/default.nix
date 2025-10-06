{ pkgs }:

pkgs.buildGoModule {
  pname = "payments-cli";
  version = "0.5.0";

  src = ./.;

  vendorHash = null;

  subPackages = [
    "cmd/payments-cli"
    "cmd/deposit-manager"
  ];

  buildInputs = with pkgs; [
    jq
    bc
  ];

  meta = with pkgs.lib; {
    description = "CLI for managing payments and deposits with Ledger integration";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
  };
}
