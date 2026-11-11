import subprocess

provider = subprocess.Popen(["build/tests/bridge-provider", "provider"], stdout=subprocess.PIPE, text=True)
try:
    if provider.stdout.readline().strip() != "ready":
        raise RuntimeError("Bridge provider did not start")
    subprocess.run(["build/tests/bridge-client", "client"], check=True, timeout=15)
    if provider.wait(timeout=3) != 0:
        raise RuntimeError("Bridge provider failed")
finally:
    if provider.poll() is None:
        provider.terminate()
        provider.wait(timeout=3)
