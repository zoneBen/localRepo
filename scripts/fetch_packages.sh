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
    # mkdir -p "$tmpdir"
    chown _apt:_apt "$tmpdir"
    cd "$tmpdir" || exit

    # 根据架构选择源地址
    if [[ "$arch" == "arm64" ]]; then
        baseurl="http://ports.ubuntu.com/ubuntu-ports"
    else
        baseurl="http://archive.ubuntu.com/ubuntu"
    fi

    # 创建临时源列表
    cat > sources.list <<EOF
deb [arch=$arch] $baseurl $codename main restricted universe multiverse
deb [arch=$arch] $baseurl $codename-updates main restricted universe multiverse
deb [arch=$arch] http://security.ubuntu.com/ubuntu $codename-security main restricted universe multiverse
EOF

    # 使用自定义源更新包列表
    sudo apt update -o Dir::Etc::sourcelist="$tmpdir/sources.list" \
                    -o Dir::Etc::sourceparts="-" \
                    --allow-unauthenticated

    # 下载主包和依赖
    sudo apt download "$package"

    deps=$(apt-rdepends --state-follow=Installed --show=Dependencies "$package" | grep -v "^ ")
    for dep in $deps; do
        sudo apt download "$dep" 2>/dev/null || true
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