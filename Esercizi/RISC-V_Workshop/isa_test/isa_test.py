import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

RED = "\033[31m"
GREEN = "\033[32m"
BOLD = '\033[1m'
UNDERLINE='\033[4m'
NC='\033[0m'

isa_test_path = "isa_test"
sim_path = os.environ.get("SIM", f"./obj_dir-{platform.system()}-{platform.machine()}/Vtop")

def run_isa_test(testname):
    clean_testname = testname.removesuffix(".S")
    bin_path = "build/" + clean_testname + ".bin"
    test_result = subprocess.run(
        [sim_path, "-e", bin_path, "--max-time", "10000"],
        stdout=subprocess.DEVNULL,
    ).returncode

    if testname == "base/fail.S":
        # fail.S test is supposed to fail so if it fails its ok
        if test_result != 0:
            test_result = 0
        else:
            # if it doesnt fail then something is wrong
            test_result = -1

    if test_result != 0:
        print(f"{RED}TEST: {testname} FAILED{NC}")
        print(f"EXIT STATUS {test_result}")
        print("")
        fail_dir = Path("fails") / clean_testname
        fail_dir.mkdir(parents=True, exist_ok=True)
        for artifact in [Path("build") / f"{clean_testname}.dmp", Path("waveform.vcd")]:
            if artifact.exists():
                shutil.move(str(artifact), fail_dir / artifact.name)
        return False

    return True

def print_results(num_test, num_pass, num_fail):
    if(num_fail != 0):
        print(f"{UNDERLINE}RESULTS{NC}")
        print(f"{RED}[{num_fail}/{num_test}] TEST FAILED{NC}")
        print(f"{GREEN}[{num_pass}/{num_test}] TEST PASSED{NC}")
    else:
        print(f"{GREEN}ALL [{num_pass}/{num_test}] TESTS PASSED{NC}")
    print("")

def run_isa_test_folder(folder):
    num_pass = 0
    num_fail = 0
    num_test = 0
    test_path = f"{isa_test_path}/{folder}"
    
    print(f"{BOLD}STARTING {folder} TESTS...{NC}")
    
    for test in os.listdir(test_path):
        num_test += 1
        subprocess.run(["make", "-s", "_isa_test", f"ISA_TEST={folder}/{test}"], check=True)

        if run_isa_test(f"{folder}/{test}"):
            num_pass += 1
        else:
            num_fail += 1
    
    print_results(num_test, num_pass, num_fail)


if __name__ == "__main__":
    # Parse arguments
    test_groups_list = sys.argv[1].split(" ")
    for test_group in test_groups_list:
        run_isa_test_folder(test_group)
