class ArmNoneEabiGccLinaro < Formula
  homepage "http://www.linaro.org/"
  url "http://releases.linaro.org/14.11/components/toolchain/gcc-linaro/4.8/gcc-linaro-4.8-2014.11.tar.xz"
  sha1 "402cfd5fe5c72bed1da40e8c6aa8d1321d0ef289"

  resource "binutils" do
    url "http://ftpmirror.gnu.org/binutils/binutils-2.25.tar.gz"
    mirror "http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.gz"
    sha1 "f10c64e92d9c72ee428df3feaf349c4ecb2493bd"
  end
  resource "newlib" do
    url "ftp://sourceware.org/pub/newlib/newlib-2.2.0-1.tar.gz"
    sha1 "ab7d18171fb02f4647881c91be52bbf19882ad3d"
  end

  depends_on "gmp"
  depends_on "libmpc"
  depends_on "mpfr"
  depends_on "cloog"
  depends_on "isl"

  conflicts_with "arm-none-eabi-binutils", :because => "We install our own version"

  fails_with :clang do
    cause "Host compiler and target newlib bootstrap need incompatible CFLAGS"
  end

  def install
    mkdir "build" do
      # binutils installs happily as a separate package, but gcc breaks if
      # it isn't installed with the same prefix.
      # So to play nicely with homebrew's package organization model, we
      # need to build it as part of the same formula.
      resource("binutils").stage do
        system "./configure", "--disable-debug",
                              "--disable-dependency-tracking",
                              "--program-prefix=arm-none-eabi-",
                              "--target=arm-none-eabi",
                              "--prefix=#{prefix}",
                              "--infodir=#{info}",
                              "--mandir=#{man}",
                              "--disable-werror",
                              "--enable-interwork",
                              "--enable-multilib",
                              "--enable-64-bit-bfd",
                              "--enable-targets=all"
        system "make"
        system "make", "install"
      end

      system "../configure", "--prefix=#{prefix}",
                             "--target=arm-none-eabi",
                             "--enable-languages=c,c++",
                             "--program-prefix=arm-none-eabi-",
                             "--with-gmp=#{Formula["gmp"].opt_prefix}",
                             "--with-mpfr=#{Formula["mpfr"].opt_prefix}",
                             "--with-mpc=#{Formula["libmpc"].opt_prefix}",
                             "--with-cloog=#{Formula["cloog"].opt_prefix}",
                             "--with-isl=#{Formula["isl"].opt_prefix}",
                             "--with-newlib",
                             "--mandir=#{man}",
                             "--disable-nls",
                             "--enable-multilib",
                             "--enable-interwork",
                             "--disable-shared",
                             "--disable-threads",
                             "--disable-libssp",
                             "--disable-libstdcxx-pch",
                             "--disable-libmudflap",
                             "--disable-libgomp",
                             "--with-python=no"
      system "make", "all-gcc"
      system "make", "install-gcc"

      ENV["PATH"] = ENV["PATH"]+":#{prefix}/bin"

      resource("newlib").stage do
        system "./configure", "--prefix=#{prefix}",
                              "--target=arm-none-eabi",
                              "--enable-interwork",
                              "--enable-multilib",
                              "--disable-libssp",
                              "--disable-nls"
        system "make"
	# newlib's make install isn't parallel-safe, but we don't want
	# to deparallelize everything just for that.
        system "make", "-j1", "install"
      end

      system "make"
      system "make", "install"
    end
  end

  test do
    system "arm-none-eabi-gcc", "--version"
  end
end
