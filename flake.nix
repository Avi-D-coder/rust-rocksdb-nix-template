{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.dream2nix = { url = "github:nix-community/dream2nix"; inputs.nixpkgs.follows = "nixpkgs"; };
  inputs.fenix = { url = "github:nix-community/fenix"; inputs.nixpkgs.follows = "nixpkgs"; };

  outputs = { self, nixpkgs, dream2nix, fenix }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      channelVersion = "nightly";
      date = "2022-12-05";
      toolchain = fenix.packages.x86_64-linux.toolchainOf {
        channel = channelVersion;
        inherit date;
        sha256 = "sha256-ds789KOM8O1eD1QN0AvYYmJQA9T+G4Vk79YnAVPiYmo=";
      };
    in
    nixpkgs.lib.recursiveUpdate
      (dream2nix.lib.makeFlakeOutputs {
        systems = [ "x86_64-linux" ];
        config.projectRoot = ./.;
        source = ./.;
        packageOverrides.rocksdb-example =
          {
            set-toolchain.overrideRustToolchain = old: { inherit (toolchain) cargo rustc; };
            zstd-sys = {
              propagatedBuildInputs = (with pkgs; [ zstd ]);
              nativeBuildInputs = old: old ++ (with pkgs; [
                pkg-config
              ]);
            };
            rocksdb = rec {
              LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
              ROCKSDB_LIB_DIR = "${pkgs.rocksdb}/lib";
              LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;

              # Everything I can think of that might solve:
              # `rocksdb/include/rocksdb/c.h:65:10: fatal error: 'stdarg.h' file not found`

              # propagatedBuildInputs = (with pkgs; [ rocksdb zlib zstd  ]);
              buildInputs = (with pkgs; [ rocksdb zlib zstd pkg-config ]);
              nativeBuildInputs = old: old ++ (with pkgs;
                [ llvm llvmPackages.libclang llvmPackages.libcxxClang llvmPackages.clang-unwrapped pkg-config ]);
            };
          };
      })
      {
        checks.x86_64-linux.rocksdb-example = self.packages.x86_64-linux.rocksdb-example;

        devShells.x86_64-linux.default =
          pkgs.mkShell rec {
            nativeBuildInputs = with pkgs; [
              llvm
              clang
              llvmPackages.libclang
              llvmPackages.libcxxClang
              toolchain.rustc
              toolchain.cargo
            ];

            buildInputs = with pkgs; [
              pkg-config
              rocksdb
              zlib
              zstd
            ];

            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath buildInputs;
            LIBCLANG_PATH = "${pkgs.llvmPackages.libclang.lib}/lib";
          };
      };
}
