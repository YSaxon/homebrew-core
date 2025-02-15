class Vitess < Formula
  desc "Database clustering system for horizontal scaling of MySQL"
  homepage "https://vitess.io"
  url "https://github.com/vitessio/vitess/archive/refs/tags/v19.0.0.tar.gz"
  sha256 "71e67b8047af40d9954ad09f15f6d91e784dc0258788850c3fd29b9fae8b6151"
  license "Apache-2.0"

  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma:   "7ab74f9fbbbf7923d49a194ebecbee72ad3893c4daa9c9320d31a4c7d91514c8"
    sha256 cellar: :any_skip_relocation, arm64_ventura:  "37d2a359a92f5a923feb8ae4832f9b189f70d0cbae6d8468760f11565e2d7452"
    sha256 cellar: :any_skip_relocation, arm64_monterey: "541effc7eeb79d76ec8caa363cfeab8571bdfd810c85548f4175f311b57f7151"
    sha256 cellar: :any_skip_relocation, sonoma:         "bb3a91655fe7e6d0159bee772d0bf8fd87fa92705b2ab3aba558f8e49d01f373"
    sha256 cellar: :any_skip_relocation, ventura:        "82cbc69d277c4a9d16eb75756f2436c5b4b1c6f48662ac301ff10a0fea4d2659"
    sha256 cellar: :any_skip_relocation, monterey:       "36ad01b0a735231ac3a917be3defff628a065f3c26507b3f403b3a40299c9f0d"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "e32f5b7f3cae9b1f9d767417ae21c4d55ea6280804eda8bb13bf43cee9ab4bc7"
  end

  depends_on "go" => :build
  depends_on "etcd"

  def install
    # -buildvcs=false needed for build to succeed on Go 1.18.
    # It can be removed when this is no longer the case.
    system "make", "install-local", "PREFIX=#{prefix}", "VTROOT=#{buildpath}", "VT_EXTRA_BUILD_FLAGS=-buildvcs=false"
    pkgshare.install "examples"
  end

  test do
    ENV["ETCDCTL_API"] = "2"
    etcd_server = "localhost:#{free_port}"
    cell = "testcell"

    fork do
      exec Formula["etcd"].opt_bin/"etcd", "--enable-v2=true",
                                           "--data-dir=#{testpath}/etcd",
                                           "--listen-client-urls=http://#{etcd_server}",
                                           "--advertise-client-urls=http://#{etcd_server}"
    end
    sleep 3

    fork do
      exec Formula["etcd"].opt_bin/"etcdctl", "--endpoints", "http://#{etcd_server}",
                                    "mkdir", testpath/"global"
    end
    sleep 1

    fork do
      exec Formula["etcd"].opt_bin/"etcdctl", "--endpoints", "http://#{etcd_server}",
                                    "mkdir", testpath/cell
    end
    sleep 1

    fork do
      exec bin/"vtctl", "--topo_implementation", "etcd2",
                        "--topo_global_server_address", etcd_server,
                        "--topo_global_root", testpath/"global",
                        "VtctldCommand", "AddCellInfo",
                        "--root", testpath/cell,
                        "--server-address", etcd_server,
                        cell
    end
    sleep 1

    port = free_port
    fork do
      exec bin/"vtgate", "--topo_implementation", "etcd2",
                         "--topo_global_server_address", etcd_server,
                         "--topo_global_root", testpath/"global",
                         "--tablet_types_to_wait", "PRIMARY,REPLICA",
                         "--cell", cell,
                         "--cells_to_watch", cell,
                         "--port", port.to_s
    end
    sleep 3

    output = shell_output("curl -s localhost:#{port}/debug/health")
    assert_equal "ok", output
  end
end
