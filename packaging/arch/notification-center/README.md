# Experimental Refined notification center package

See [design, source evidence and independent rollback](../../../docs/notification-center.md).
`arch-upstream.PKGBUILD` preserves Arch maintainers' original recipe; `stock-files.txt`
is the installed official 1:1.9.0-1 inventory used to reject additional/missing paths.
The local recipe rebuilds the whole multicall bundle, with changes confined to the
notification applet. Other applet source and packaged service definitions stay stock.
The patch is GPL-3.0-only; packaging utilities are MPL-2.0. No global libcosmic patch
or daemon dependency is added. Refined center visuals are default-on only in this
explicitly installed custom package, independently of the banner package.

Run `bash scripts/notification-center-package-test.sh build` from the repository.
It stages the canonical patch beside the recipe in a temporary directory. Do not
run this recipe directly without copying the canonical patch listed in `source`.
The helper never installs build dependencies, restarts processes or logs out.
Build/visual readiness is recorded in docs; fixture checks alone do not prove it.

The host helper checks stock version/ownership and isolates Git configuration only
in the build subprocess to prevent the global GitHub HTTPS-to-SSH rewrite. Cargo
uses normal network access and Git CLI fetching. No global configuration changes
or sandbox network build attempts are needed. See the host command in the linked
documentation; compilation remains unverified until the host build succeeds.
