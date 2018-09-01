class Nsq < Formula
  desc "Realtime distributed messaging platform"
  homepage "https://nsq.io/"
  url "https://github.com/nsqio/nsq/archive/v1.1.0.tar.gz"
  version "1.1.0"
  sha256 "85cb15cc9a7b50e779bc8e76309cff9bf555b2f925c2c8abe81d28d690fb1940"
  revision 1
  head "https://github.com/nsqio/nsq.git"

  bottle do
    cellar :any_skip_relocation
    sha256 "12610284372b58cdc9957d40bcbf0ecb4ee2cc05014a3b522d4ffa079f82317a" => :mojave
    sha256 "bf7029656b4cf5fbefaa252ed1cac50dc49a31139eda7b583165bfcacaec1e42" => :high_sierra
    sha256 "5bb322677d0bbb1f4f5fa7be1584cafbfcec01e67c0063f6ee14a13933389c6e" => :sierra
    sha256 "2f04a20ef5c05ddd00893198ca5134a455869d1a231893d7931603c60a4dd497" => :el_capitan
  end

  depends_on "go" => :build
  depends_on "dep" => :build

  def install
    ENV["GOPATH"] = buildpath
    (buildpath/"src/github.com/nsqio/nsq").install buildpath.children
    cd "src/github.com/nsqio/nsq" do
      system "dep", "ensure"
      system "make", "DESTDIR=#{prefix}", "PREFIX=", "install"
    end
  end

  def post_install
    (var/"log").mkpath
    (var/"nsq").mkpath
  end

  plist_options :manual => "nsqd -data-path=#{HOMEBREW_PREFIX}/var/nsq"

  def plist; <<~EOS
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{bin}/nsqd</string>
        <string>-data-path=#{var}/nsq</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{var}/nsq</string>
      <key>StandardErrorPath</key>
      <string>#{var}/log/nsqd.error.log</string>
      <key>StandardOutPath</key>
      <string>#{var}/log/nsqd.log</string>
    </dict>
    </plist>
  EOS
  end

  test do
    begin
      lookupd = fork do
        exec bin/"nsqlookupd"
      end
      sleep 2
      d = fork do
        exec bin/"nsqd", "--lookupd-tcp-address=127.0.0.1:4160"
      end
      sleep 2
      admin = fork do
        exec bin/"nsqadmin", "--lookupd-http-address=127.0.0.1:4161"
      end
      sleep 2
      to_file = fork do
        exec bin/"nsq_to_file", "--lookupd-http-address=127.0.0.1:4161",
                                "--output-dir=#{testpath}",
                                "--topic=test"
      end
      sleep 2
      system "curl", "-d", "hello", "http://127.0.0.1:4151/pub?topic=test"
      sleep 2
      dat = File.read(Dir["*.dat"].first)
      assert_match "test", dat
      assert_match version.to_s, dat
    ensure
      Process.kill(9, lookupd)
      Process.kill(9, d)
      Process.kill(9, admin)
      Process.kill(9, to_file)
      Process.wait lookupd
      Process.wait d
      Process.wait admin
      Process.wait to_file
    end
  end
end
