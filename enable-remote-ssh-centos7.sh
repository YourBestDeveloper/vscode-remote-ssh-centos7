#!/bin/bash

set -e

# SCL repository rewrite function (to avoid duplication)
setup_scl_repos() {
  echo "Rewriting SCL repositories to vault.centos.org..."
  
  cat > /etc/yum.repos.d/CentOS-SCLo-scl.repo << 'EOFSCL'
[centos-sclo-sclo]
name=CentOS-7 - SCLo sclo
baseurl=http://vault.centos.org/centos/7/sclo/x86_64/sclo/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo
skip_if_unavailable=1
EOFSCL
  
  cat > /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo << 'EOFSCL'
[centos-sclo-rh]
name=CentOS-7 - SCLo rh
baseurl=http://vault.centos.org/centos/7/sclo/x86_64/rh/
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo
skip_if_unavailable=1
EOFSCL
  
  echo "SCL repositories rewrite complete"
}

# 1) Check root privileges
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root. Try sudo or su." >&2
  exit 1
fi

# 1a) Execution time notice and confirmation
echo "Notice: This task may take 15-25 minutes depending on your processor performance. Proceed? (y/n)" >&2
read -r user_input
if [[ "$user_input" != "y" && "$user_input" != "Y" ]]; then
  echo "Aborted." >&2
  exit 1
fi

# 2) CentOS 7 EOL handling - Change to vault.centos.org (EOL: June 30, 2024)
echo "Changing CentOS 7 repositories to vault.centos.org..."
if grep -q "mirrorlist.centos.org" /etc/yum.repos.d/CentOS-Base.repo 2>/dev/null; then
  # Backup existing repo files
  cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup 2>/dev/null || true
  
  # Comment out mirrorlist and change baseurl to vault.centos.org
  sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/CentOS-*.repo
  sed -i 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo
  
  echo "CentOS 7 repository change complete"
fi

# Clean yum cache
yum clean all || true

# Disable problematic repositories (prevent network errors)
# Temporarily disable endpoint repository if exists
if [ -f /etc/yum.repos.d/endpoint.repo ]; then
  sed -i 's/enabled=1/enabled=0/g' /etc/yum.repos.d/endpoint.repo || true
  echo "Endpoint repository disabled (network error prevention)"
fi

# If SCL repositories exist, backup and rewrite
if [ -f /etc/yum.repos.d/CentOS-SCLo-scl.repo ] || [ -f /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo ]; then
  echo "Existing SCL repositories found"
  [ -f /etc/yum.repos.d/CentOS-SCLo-scl.repo ] && cp /etc/yum.repos.d/CentOS-SCLo-scl.repo /etc/yum.repos.d/CentOS-SCLo-scl.repo.backup 2>/dev/null || true
  [ -f /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo ] && cp /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo /etc/yum.repos.d/CentOS-SCLo-scl-rh.repo.backup 2>/dev/null || true
  setup_scl_repos
fi

yum makecache fast 2>/dev/null || yum makecache 2>/dev/null || echo "Cache creation partially failed (ignoring and continuing)"

# 3) Enable EPEL repository (for patchelf and other required packages)
yum install -y epel-release

# EPEL EOL handling
if [ -f /etc/yum.repos.d/epel.repo ]; then
  sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/epel.repo
  sed -i 's|#baseurl=http://download.fedoraproject.org/pub/epel|baseurl=http://archives.fedoraproject.org/pub/archive/epel|g' /etc/yum.repos.d/epel.repo
fi

# 4) Install required packages (for CentOS 7)
# Install Development Tools group (includes gcc, make, autoconf, etc.)
yum groupinstall -y "Development Tools" --skip-broken || yum groupinstall -y "Development Tools"

# Install additional required packages
yum install -y --skip-broken wget patchelf bison gawk m4 texinfo \
gcc gcc-c++ gdb gperf flex help2man \
ncurses-devel autoconf automake libtool \
bzip2 xz unzip patch rsync

# 4a) Install SCL (Software Collections) repository and devtoolset
# glibc 2.28 build requires gcc 6.2+ and make 4.0+
echo "Installing devtoolset-9... (includes gcc 9.x, make 4.x)"

# Check if centos-release-scl is already installed
if ! rpm -q centos-release-scl &>/dev/null; then
  yum install -y centos-release-scl
  
  # Rewrite newly created SCL repository files (EOL handling)
  setup_scl_repos
  
  yum clean all || true
  yum makecache fast 2>/dev/null || yum makecache 2>/dev/null || echo "Cache creation partially failed (ignoring and continuing)"
else
  echo "centos-release-scl already installed"
fi

# Install devtoolset-9 (only gcc, g++, make needed - libstdc++ will be built separately)
echo "Starting devtoolset-9 package installation..."
yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-binutils devtoolset-9-make \
  --skip-broken 2>&1 | tee /tmp/devtoolset-install.log 2>/dev/null || {
  echo "Warning: Some errors occurred during devtoolset-9 installation. Retrying..."
  yum clean all || true
  yum install -y devtoolset-9-gcc devtoolset-9-gcc-c++ devtoolset-9-binutils devtoolset-9-make
}
echo "devtoolset-9 installation complete"

# Activate devtoolset-9 environment
source /opt/rh/devtoolset-9/enable

# Check and display versions
echo "=== Build Tools Version Check ==="
gcc --version | head -1
g++ --version | head -1
make --version | head -1
echo "=============================="

# 4b) Build libstdc++.so.6 (provides GLIBCXX_3.4.21+ required by VS Code)
echo ""
echo "=== Building libstdc++.so.6 (GLIBCXX_3.4.21+ support) ==="
echo "This task will take 5-10 minutes..."

LIBSTDCXX_INSTALL_PREFIX="/opt/gcc9-runtime"

# Check if already installed
EXISTING_VERSION=""
SKIP_LIBSTDCXX_BUILD=false

if [ -f "/opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6" ]; then
    EXISTING_VERSION=$(strings /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6 2>/dev/null | grep "GLIBCXX_3.4.21" || echo "")
    if [ -n "$EXISTING_VERSION" ]; then
        echo "✓ libstdc++.so.6 (GLIBCXX_3.4.21+) already installed. Skipping."
        SKIP_LIBSTDCXX_BUILD=true
    else
        echo "⚠ libstdc++.so.6 exists but version is too old. Rebuilding."
        rm -f /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6* 2>/dev/null || true
    fi
fi

if [ "$SKIP_LIBSTDCXX_BUILD" = false ]; then
    cd /tmp
    
    # Clean up existing build directory
    rm -rf gcc-9.3.0* 2>/dev/null || true
    
    echo "→ Downloading gcc 9.3.0 source..."
    wget -q --show-progress http://ftp.gnu.org/gnu/gcc/gcc-9.3.0/gcc-9.3.0.tar.xz
    tar -xf gcc-9.3.0.tar.xz
    cd gcc-9.3.0
    
    echo "→ Downloading build dependencies..."
    ./contrib/download_prerequisites
    
    echo "→ Configuring libstdc++-v3 build..."
    mkdir build && cd build
    
    ../configure \
      --prefix="$LIBSTDCXX_INSTALL_PREFIX" \
      --enable-languages=c++ \
      --disable-multilib \
      --disable-bootstrap \
      --disable-libsanitizer \
      --disable-libvtv \
      --disable-libquadmath
    
    echo "→ Building libstdc++-v3... (parallel build: $(nproc) cores)"
    make -j"$(nproc)" all-target-libstdc++-v3
    
    echo "→ Installing libstdc++-v3..."
    make install-target-libstdc++-v3
    
    # Copy to devtoolset-9 directory
    echo "→ Copying to devtoolset-9 directory..."
    # Copy from lib64 or lib directory
    if [ -d "$LIBSTDCXX_INSTALL_PREFIX/lib64" ]; then
        cp -v "$LIBSTDCXX_INSTALL_PREFIX/lib64/libstdc++.so.6"* /opt/rh/devtoolset-9/root/usr/lib64/
    else
        cp -v "$LIBSTDCXX_INSTALL_PREFIX/lib/libstdc++.so.6"* /opt/rh/devtoolset-9/root/usr/lib64/
    fi
    
    # Verify version
    echo ""
    echo "=== libstdc++.so.6 Version Check ==="
    ls -la /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6*
    echo ""
    echo "Supported GLIBCXX versions (latest 10):"
    strings /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6 | grep GLIBCXX | tail -10
    echo ""
    echo "Supported CXXABI versions (latest 5):"
    strings /opt/rh/devtoolset-9/root/usr/lib64/libstdc++.so.6 | grep CXXABI | tail -5
    echo "=============================="
    
    # Clean up build temporary files
    cd /tmp
    rm -rf gcc-9.3.0 gcc-9.3.0.tar.xz 2>/dev/null || true
    
    echo "✅ libstdc++.so.6 build and installation complete"
else
    echo "✓ libstdc++.so.6 build skipped"
fi
echo ""

# 5) Download and prepare glibc 2.28 build
GLIBC_VERSION="2.28"
GLIBC_SRC="glibc-$GLIBC_VERSION"
INSTALL_PREFIX="/opt/$GLIBC_SRC"

# Check if already installed
SKIP_GLIBC_BUILD=false
if [ -f "$INSTALL_PREFIX/lib/libc.so.6" ]; then
    # Use compatible method instead of grep -oP
    INSTALLED_GLIBC_VERSION=$("$INSTALL_PREFIX/lib/libc.so.6" 2>/dev/null | head -1 | sed -n 's/.*version \([0-9.]*\).*/\1/p' || echo "")
    if [ "$INSTALLED_GLIBC_VERSION" = "$GLIBC_VERSION" ]; then
        echo "✓ glibc $GLIBC_VERSION already installed. Skipping build."
        SKIP_GLIBC_BUILD=true
    elif [ -n "$INSTALLED_GLIBC_VERSION" ]; then
        echo "⚠ Different version of glibc($INSTALLED_GLIBC_VERSION) is installed. Rebuilding."
    fi
fi

if [ "$SKIP_GLIBC_BUILD" = false ]; then
    cd /tmp
    
    # Clean up existing files
    rm -rf "$GLIBC_SRC" "${GLIBC_SRC}.tar.gz" 2>/dev/null || true
    
    echo "=== Downloading and preparing glibc 2.28 build ==="
    wget http://ftp.gnu.org/gnu/libc/"${GLIBC_SRC}.tar.gz"
    tar -xzf "${GLIBC_SRC}.tar.gz"
    mkdir -p "$GLIBC_SRC/build"
    cd "$GLIBC_SRC/build"

    # Reactivate devtoolset-9 (to work in new subshell)
    source /opt/rh/devtoolset-9/enable
    
    # Temporarily unset LD_LIBRARY_PATH to avoid glibc configure error
    # (glibc configure fails if LD_LIBRARY_PATH contains current directory)
    SAVED_LD_LIBRARY_PATH="$LD_LIBRARY_PATH"
    unset LD_LIBRARY_PATH

    echo "=== Building glibc 2.28 ==="
    ../configure --prefix="$INSTALL_PREFIX" --disable-werror
    make -j"$(nproc)"
    make install
    echo "=== glibc 2.28 build complete ==="
    
    # Restore LD_LIBRARY_PATH
    export LD_LIBRARY_PATH="$SAVED_LD_LIBRARY_PATH"
    
    # Clean up temporary files
    cd /tmp
    rm -rf "$GLIBC_SRC" "${GLIBC_SRC}.tar.gz" 2>/dev/null || true
else
    echo "✓ glibc 2.28 build skipped"
fi

# 6) Register environment variables - /etc/profile.d/vscode-glibc.sh
LINKER="$INSTALL_PREFIX/lib/ld-$GLIBC_VERSION.so"
LIBPATH="$INSTALL_PREFIX/lib"

# Check patchelf path
PATCHELF="$(which patchelf 2>/dev/null || echo "")"
if [ -z "$PATCHELF" ]; then
    echo "⚠ Warning: patchelf not found. Assuming /bin/patchelf."
    PATCHELF="/bin/patchelf"
fi

# Add devtoolset-9 libstdc++ path (includes GLIBCXX_3.4.20, 3.4.21 and newer versions)
DEVTOOLSET_LIB="/opt/rh/devtoolset-9/root/usr/lib64"

cat > /etc/profile.d/vscode-glibc.sh << EOF
# VS Code Server custom glibc configuration - profile.d
export VSCODE_SERVER_CUSTOM_GLIBC_LINKER=$LINKER
export VSCODE_SERVER_CUSTOM_GLIBC_PATH=$LIBPATH:$DEVTOOLSET_LIB:/usr/lib64:/lib64
export VSCODE_SERVER_PATCHELF_PATH=$PATCHELF

# Add devtoolset-9 library path with priority to LD_LIBRARY_PATH
# (Required for latest version of libstdc++.so.6)
export LD_LIBRARY_PATH=$DEVTOOLSET_LIB:\${LD_LIBRARY_PATH}
EOF

chmod +x /etc/profile.d/vscode-glibc.sh

# Same configuration for /etc/environment (idempotency: remove existing settings then add)
sed -i '/VSCODE_SERVER_CUSTOM_GLIBC_LINKER=/d' /etc/environment
sed -i '/VSCODE_SERVER_CUSTOM_GLIBC_PATH=/d' /etc/environment
sed -i '/VSCODE_SERVER_PATCHELF_PATH=/d' /etc/environment
sed -i '/^LD_LIBRARY_PATH=.*devtoolset-9/d' /etc/environment

echo "VSCODE_SERVER_CUSTOM_GLIBC_LINKER=$LINKER" >> /etc/environment
echo "VSCODE_SERVER_CUSTOM_GLIBC_PATH=$LIBPATH:$DEVTOOLSET_LIB:/usr/lib64:/lib64" >> /etc/environment
echo "VSCODE_SERVER_PATCHELF_PATH=$PATCHELF" >> /etc/environment
echo "LD_LIBRARY_PATH=$DEVTOOLSET_LIB:\$LD_LIBRARY_PATH" >> /etc/environment

# 7) Completion message
echo "=========================================="
echo "glibc $GLIBC_VERSION installation complete!"
echo "=========================================="
echo "Installation location: $INSTALL_PREFIX"
echo ""
echo "VS Code Server environment variable configuration files:"
echo "  - /etc/profile.d/vscode-glibc.sh"
echo "  - /etc/environment"
echo ""
echo "Configured environment variables:"
echo "  - VSCODE_SERVER_CUSTOM_GLIBC_LINKER=$LINKER"
echo "  - VSCODE_SERVER_CUSTOM_GLIBC_PATH=$LIBPATH:$DEVTOOLSET_LIB:/usr/lib64:/lib64"
echo "  - VSCODE_SERVER_PATCHELF_PATH=$PATCHELF"
echo "  - LD_LIBRARY_PATH=$DEVTOOLSET_LIB:\$LD_LIBRARY_PATH"
echo ""
echo "Main libraries included:"
echo "  - glibc 2.28 (modern glibc)"
echo "  - libstdc++.so.6 from gcc 9.3.0 (GLIBCXX_3.4.21+, CXXABI_1.3.9+)"
echo ""
echo "✅ These settings will be automatically applied in new SSH sessions."
echo "✅ VS Code Remote SSH will work correctly."
echo ""
echo "Note:"
echo "  - This script can be re-run (idempotent)"
echo "  - Already installed components will be automatically skipped"
echo "=========================================="
