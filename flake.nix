{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }: {
    devShell = nixpkgs.mkShell {
      nativeBuildInputs = [ self.nixpkgs.tailwindcss ];
    };
  };
}
