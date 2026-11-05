# Copyright 2026 Vladislav Lukianov
# Distributed under the terms of the GNU General Public License v2

EAPI=8

DESCRIPTION="Interactive tmux session picker for SSH logins"
HOMEPAGE="https://github.com/vlad-lukyanov/tmux-login"
LICENSE="MIT"
SLOT="0"
KEYWORDS="~amd64 ~arm64 ~x86"

RDEPEND="
	>=app-shells/bash-4.4
	app-misc/tmux
"

src_install() {
	dobin "${FILESDIR}/tmux-login"
	dobin "${FILESDIR}/tmux-login-enable"

	doman "${FILESDIR}/tmux-login.1"
	doman "${FILESDIR}/tmux-login-enable.1"

	dodoc "${FILESDIR}/README.md" "${FILESDIR}/LICENSE"
}

pkg_postinst() {
	elog "To enable the tmux session picker on SSH login, run as your user:"
	elog "  tmux-login-enable"
	elog "To disable it later:"
	elog "  tmux-login-enable --remove"
}
