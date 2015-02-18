class MingwW64 < Formula
  homepage "http://mingw-w64.sourceforge.net/"
  url "http://ufpr.dl.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v3.3.0.tar.bz2"
  sha1 "d31eac960d42e791970697eae5724e529c81dcd6"

  resource "binutils" do
    url "http://ftpmirror.gnu.org/binutils/binutils-2.25.tar.gz"
    mirror "http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.gz"
    sha1 "f10c64e92d9c72ee428df3feaf349c4ecb2493bd"
  end
  resource "gcc" do
    url "http://ftpmirror.gnu.org/gcc/gcc-4.9.2/gcc-4.9.2.tar.bz2"
    mirror "ftp://gcc.gnu.org/pub/gcc/releases/gcc-4.9.2/gcc-4.9.2.tar.bz2"
    sha1 "79dbcb09f44232822460d80b033c962c0237c6d8"
  end

  depends_on "gmp"
  depends_on "libmpc"
  depends_on "mpfr"
  depends_on "cloog"
  depends_on "isl"

  # The makeinfo that ships with MacOS has a bug that folds '--' in a pathname
  # to '-', and the homebrew build environment exercises that when gcc tries
  # to build its documentation in the resource staging directory.
  # So we need to force a newer texinfo to be used.
  depends_on "texinfo" => :build

  def install
    target = "x86_64-w64-mingw32"
    base_configure_args = ["--prefix=#{prefix}",
                           "--with-sysroot=#{prefix}",
                           "--disable-debug",
                           "--disable-dependency-tracking",
                           "--disable-nls",
                           "--program-prefix=#{target}-",
                           "--infodir=#{info}/#{target}",
                           "--target=#{target}",
                           "--enable-targets=x86_64-w64-mingw32,i686-w64-mingw32"]

    # binutils installs happily as a separate package, but gcc breaks if
    # it isn't installed with the same prefix.
    # So to play nicely with homebrew's package organization model, we
    # need to build it as part of the same formula.
    resource("binutils").stage do
      system "./configure", *base_configure_args,
                            "--disable-werror",
                            "--enable-interwork",
                            "--enable-multilib"
      system "make"
      system "make", "install"
    end

    ENV["PATH"] = ENV["PATH"]+":#{prefix}/bin"

    chdir "mingw-w64-headers" do
      system "./configure", "--prefix=#{prefix}/#{target}",
                            "--host=#{target}"
      system "make", "install"
    end

    # GCC expects the things mingw-w64 wants in #{prefix}/#{target} to be
    # in #{prefix}/mingw
    system "ln", "-s", "#{prefix}/#{target}", "#{prefix}/mingw"

    # We need lib and lib64 to be synonyms for multilib to work
    system "ln", "-s", "#{prefix}/#{target}/lib", "#{prefix}/#{target}/lib64"

    resource("gcc").stage do
      mkdir "build" do

        # Make sure we find a working makeinfo
        ENV.prepend_path "PATH", "#{Formula["texinfo"].opt_bin}"

        system "../configure", *base_configure_args,
                               "--with-gmp=#{Formula["gmp"].opt_prefix}",
                               "--with-mpfr=#{Formula["mpfr"].opt_prefix}",
                               "--with-mpc=#{Formula["libmpc"].opt_prefix}",
                               "--with-cloog=#{Formula["cloog"].opt_prefix}",
                               "--with-isl=#{Formula["isl"].opt_prefix}",
                               "--enable-multilib",
                               "--enable-interwork"
        system "make", "all-gcc"
        system "make", "install-gcc"

        # Ick.
        chdir (buildpath/"mingw-w64-crt") do
          # For some reason, configure finds clang when it goes looking for
          # x86_64-w64-mingw32-gcc, so we have to tell it where to look for
          # the right one.
          system "./configure", "--prefix=#{prefix}/#{target}",
                                "--enable-lib32",
                                "--enable-lib64",
                                "--host=#{target}",
                                "CC=x86_64-w64-mingw32-gcc"
          system "make"
          system "make", "install"
        end

        # Now that libs are installed, finish GCC
        system "make"
        system "make", "install"
      end
    end
  end

  test do
    system "x86_64-w64-mingw32-gcc", "--version"
  end
end
