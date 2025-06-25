#!/bin/bash

REPO_ROOT="/home/runner/repo"
PACKAGES="
nginx
"

get_all_deps() {
    local pkg="$1"
    echo "Collecting dependencies for $pkg..."
    apt-rdepends "$pkg" | grep -v "^ "
}

download_package() {
    local codename="$1"
    local arch="$2"
    local package="$3"

    echo "Downloading $package for $codename/$arch..."

    tmpdir="/tmp/debs-$codename-$arch"
    mkdir -p "$tmpdir"
    cd "$tmpdir" || exit

    cat > /etc/apt/sources.list.d/repo.list <<EOF
deb [arch=$arch] http://archive.ubuntu.com/ubuntu $codename main restricted universe multiverse
deb [arch=$arch] http://archive.ubuntu.com/ubuntu $codename-updates main restricted universe multiverse
deb [arch=$arch] http://archive.ubuntu.com/ubuntu $codename-backports main restricted universe multiverse
deb [arch=$arch] http://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse
EOF

    sudo apt update --allow-insecure-repositories --allow-unauthenticated

    apt-get download --architecture=$arch "$package" 
    deps=$(get_all_deps "$package")
    for dep in $deps; do
        apt-get download --architecture=$arch "$dep"  2>/dev/null || true
    done

    cd "$REPO_ROOT" || exit
    reprepro -b "$REPO_ROOT" includedeb "$codename" "$tmpdir"/*.deb

    rm -rf "$tmpdir"
}

# 主循环
for codename in bionic focal jammy noble; do
  for arch in amd64 arm64; do 
    echo "=== Processing $codename / $arch ==="
    for package in $PACKAGES; do
      download_package "$codename" "$arch" "$package"
    done
  done
done

echo "✅ All packages have been added to the repository."