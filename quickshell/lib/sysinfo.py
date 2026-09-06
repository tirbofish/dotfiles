#!/usr/bin/env python3
import glob
import json
import os
import re
import time

STATE = "/tmp/qs_sysinfo_cpu"


def read_text(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def first_glob(pattern):
    matches = sorted(glob.glob(pattern))
    return matches[0] if matches else ""


def cpu_times():
    with open("/proc/stat") as f:
        parts = f.readline().split()
    nums = [int(x) for x in parts[1:9]]
    idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
    total = sum(nums)
    return idle, total


def cpu_pct():
    idle, total = cpu_times()
    prev = read_text(STATE).split()
    if len(prev) != 2:
        time.sleep(0.12)
        idle2, total2 = cpu_times()
        dt = total2 - total
        di = idle2 - idle
        idle, total = idle2, total2
    else:
        try:
            pi, pt = int(prev[0]), int(prev[1])
            dt = total - pt
            di = idle - pi
        except ValueError:
            dt, di = 0, 0
    pct = 0
    if dt > 0:
        pct = int(round((1.0 - (di / dt)) * 100))
    try:
        with open(STATE, "w") as f:
            f.write(f"{idle} {total}")
    except OSError:
        pass
    return max(0, min(100, pct))


def cpu_model():
    model = ""
    with open("/proc/cpuinfo") as f:
        for line in f:
            if line.startswith("model name"):
                model = line.split(":", 1)[1].strip()
                break
    short = re.search(r"i[3579]-[\w-]+", model)
    if not short:
        short = re.search(r"Ryzen\s+\d+\s+\w+", model)
    if short:
        return short.group(0)
    return model[:28] if model else "CPU"


def cpu_freq():
    freqs = []
    for path in glob.glob("/sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"):
        try:
            freqs.append(int(read_text(path)))
        except ValueError:
            pass
    if not freqs:
        return 0.0
    return round((sum(freqs) / len(freqs)) / 1_000_000, 2)


def meminfo():
    info = {}
    with open("/proc/meminfo") as f:
        for line in f:
            key, _, rest = line.partition(":")
            try:
                info[key] = int(rest.strip().split()[0])
            except (ValueError, IndexError):
                pass
    total = info.get("MemTotal", 1)
    avail = info.get("MemAvailable", 0)
    used = max(0, total - avail)
    swap_total = info.get("SwapTotal", 0)
    swap_free = info.get("SwapFree", 0)
    swap_used = max(0, swap_total - swap_free)
    return {
        "ramUsed": round(used / 1024 / 1024, 1),
        "ramTotal": round(total / 1024 / 1024, 1),
        "ramPct": int(round(100.0 * used / total)) if total else 0,
        "swapUsed": round(swap_used / 1024 / 1024, 1),
        "swapTotal": round(swap_total / 1024 / 1024, 1),
        "swapPct": int(round(100.0 * swap_used / swap_total)) if swap_total else 0,
    }


def hwmon_temps():
    cpu_temp = 0
    nvme_temp = 0
    for hw in glob.glob("/sys/class/hwmon/hwmon*"):
        name = read_text(os.path.join(hw, "name"))
        if name == "coretemp":
            chosen = ""
            for label in glob.glob(os.path.join(hw, "temp*_label")):
                if "Package" in read_text(label):
                    chosen = label.replace("_label", "_input")
                    break
            if not chosen:
                chosen = os.path.join(hw, "temp1_input")
            try:
                cpu_temp = int(round(int(read_text(chosen)) / 1000))
            except ValueError:
                pass
        elif name == "nvme" and nvme_temp == 0:
            try:
                nvme_temp = int(round(int(read_text(os.path.join(hw, "temp1_input"))) / 1000))
            except ValueError:
                pass
    return cpu_temp, nvme_temp


def battery():
    bat = first_glob("/sys/class/power_supply/BAT*")
    ac = first_glob("/sys/class/power_supply/A[CD]*")
    power_uw = 0
    energy_now = 0
    energy_full = 0
    energy_design = 0
    if bat:
        try:
            power_uw = int(read_text(os.path.join(bat, "power_now")) or "0")
        except ValueError:
            power_uw = 0
        try:
            energy_now = int(read_text(os.path.join(bat, "energy_now")) or "0")
            energy_full = int(read_text(os.path.join(bat, "energy_full")) or "0")
            energy_design = int(read_text(os.path.join(bat, "energy_full_design")) or "0")
        except ValueError:
            pass
    try:
        cap = int(read_text(os.path.join(bat, "capacity")) or "0") if bat else 0
    except ValueError:
        cap = 0
    try:
        cycles = int(read_text(os.path.join(bat, "cycle_count")) or "0") if bat else 0
    except ValueError:
        cycles = 0
    health = int(round(100.0 * energy_full / energy_design)) if energy_design else 0
    ac_online = read_text(os.path.join(ac, "online")) == "1" if ac else False
    return {
        "powerW": round(power_uw / 1_000_000, 1),
        "batPct": cap,
        "batStatus": read_text(os.path.join(bat, "status")) if bat else "",
        "batHealth": health,
        "cycles": cycles,
        "acOnline": ac_online,
        "energyNowWh": round(energy_now / 1_000_000, 1),
        "energyFullWh": round(energy_full / 1_000_000, 1),
    }


def disk():
    st = os.statvfs("/")
    total = st.f_frsize * st.f_blocks
    free = st.f_frsize * st.f_bavail
    used = total - free
    return {
        "diskUsed": round(used / 1024 / 1024 / 1024, 1),
        "diskTotal": round(total / 1024 / 1024 / 1024, 1),
        "diskPct": int(round(100.0 * used / total)) if total else 0,
    }


def uptime():
    try:
        seconds = float(read_text("/proc/uptime").split()[0])
    except (ValueError, IndexError):
        return "—"
    seconds = int(seconds)
    days, rem = divmod(seconds, 86400)
    hours, rem = divmod(rem, 3600)
    minutes = rem // 60
    if days:
        return f"{days}d {hours}h"
    if hours:
        return f"{hours}h {minutes}m"
    return f"{minutes}m"


def loadavg():
    parts = read_text("/proc/loadavg").split()
    if len(parts) >= 3:
        return parts[0], parts[1], parts[2]
    return "0", "0", "0"


def main():
    mem = meminfo()
    cpu_temp, nvme_temp = hwmon_temps()
    bat = battery()
    dsk = disk()
    l1, l5, l15 = loadavg()
    out = {
        "host": read_text("/etc/hostname") or "linux",
        "cpuModel": cpu_model(),
        "cpuPct": cpu_pct(),
        "cpuFreq": cpu_freq(),
        "cpuGov": read_text("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor"),
        "cpuTemp": cpu_temp,
        "nvmeTemp": nvme_temp,
        "load1": l1,
        "load5": l5,
        "load15": l15,
        "uptime": uptime(),
    }
    out.update(mem)
    out.update(bat)
    out.update(dsk)
    print(json.dumps(out, separators=(",", ":")))


if __name__ == "__main__":
    main()
