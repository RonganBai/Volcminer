import { spawn } from "node:child_process";

export function runCommand(command, args = [], options = {}) {
  const timeoutMs = Number.isFinite(Number(options.timeoutMs))
    ? Number(options.timeoutMs)
    : 10000;

  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"]
    });

    let stdout = "";
    let stderr = "";
    let settled = false;
    let timeout = null;

    const cleanup = () => {
      if (timeout) {
        clearTimeout(timeout);
        timeout = null;
      }
      if (options.signal) {
        options.signal.removeEventListener("abort", abortHandler);
      }
    };

    const fail = (error) => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      reject(error);
    };

    const succeed = () => {
      if (settled) {
        return;
      }
      settled = true;
      cleanup();
      resolve({
        stdout: stdout.trim(),
        stderr: stderr.trim()
      });
    };

    const abortHandler = () => {
      child.kill("SIGKILL");
      const error = new Error("Command aborted");
      error.code = "ABORT_ERR";
      fail(error);
    };

    child.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });

    child.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });

    child.on("error", (error) => {
      fail(error);
    });

    child.on("close", (code, signal) => {
      if (settled) {
        return;
      }

      if (code === 0) {
        succeed();
        return;
      }

      const details = [stderr.trim(), stdout.trim()]
        .filter(Boolean)
        .join("\n");
      const error = new Error(
        details || `Command failed: ${command} ${args.join(" ")}${signal ? ` (${signal})` : ""}`
      );
      error.code = code;
      error.signal = signal;
      fail(error);
    });

    if (timeoutMs > 0) {
      timeout = setTimeout(() => {
        child.kill("SIGKILL");
        const error = new Error(
          `Command timed out after ${timeoutMs}ms: ${command} ${args.join(" ")}`
        );
        error.code = "ETIMEDOUT";
        fail(error);
      }, timeoutMs);
    }

    if (options.signal) {
      if (options.signal.aborted) {
        abortHandler();
        return;
      }
      options.signal.addEventListener("abort", abortHandler, { once: true });
    }
  });
}
