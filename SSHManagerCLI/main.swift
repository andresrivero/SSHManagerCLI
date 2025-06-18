import Foundation

class SSHConnectionHandler {
    
    // Properties to hold our configuration ---
    private let sshPassword: String
    private let sshLogin: String
    private let localSocksPort: String
    private let sshPort: String
    
    private var sshProcess: Process?

    // The initializer now takes the configuration as arguments
    init(sshPassword: String, sshLogin: String, localSocksPort: String, sshPort: String) {
        self.sshPassword = sshPassword
        self.sshLogin = sshLogin
        self.localSocksPort = localSocksPort
        self.sshPort = sshPort
        
        print("[CONFIG] Tool configured for:")
        print("[CONFIG] -> SSH Login: \(self.sshLogin)")
        print("[CONFIG] -> SSH Port: \(self.sshPort)")
        print("[CONFIG] -> Local SOCKS Port: \(self.localSocksPort)")
    }
    
    func start() {
        print("[INFO] Starting SSH connection handler.")
        startSSHProcess()
    }
    
    func stop() {
        print("[INFO] Stopping SSH connection handler.")
        sshProcess?.terminate()
        sshProcess = nil
    }

    private func startSSHProcess() {
        guard sshProcess == nil else {
            print("[WARN] SSH process already running. Skipping.")
            return
        }

        print("[INFO] Launching new SSH process via sshpass...")
        
        sshProcess = Process()
        sshProcess?.launchPath = "/usr/local/bin/sshpass"
        
        // The arguments are now built using the properties set during initialization
        sshProcess?.arguments = [
            "-p", sshPassword,
            "ssh",
            sshLogin,
            "-p", sshPort,
            "-D", localSocksPort,
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-T"
        ]
    
        sshProcess?.terminationHandler = { [weak self] process in
            print("[ERROR] SSH process terminated. Attempting to reconnect in 5 seconds...")
            self?.sshProcess = nil
            Thread.sleep(forTimeInterval: 5.0)
            self?.startSSHProcess()
        }

        do {
            try sshProcess?.run()
            print("[SUCCESS] SSH process started via sshpass. The proxy should be active.")
        } catch {
            print("[FATAL] Failed to start sshpass process: \(error).")
            sshProcess = nil
            Thread.sleep(forTimeInterval: 5.0)
            startSSHProcess()
        }
    }
}

// Main execution block of our program

// CommandLine.arguments is an array containing the path to the program, then each argument.
// We expect 5 total items: path + 4 arguments.
guard CommandLine.arguments.count == 5 else {
    print("--- SSH Proxy Tool ---")
    print("Usage: \(CommandLine.arguments[0]) <password> <user@host> <local_socks_port> <ssh_port>")
    print("Example: \(CommandLine.arguments[0]) \"mySecret\" \"user@10.20.52.85\" 9999 2222")
    exit(1) // Exit the program if arguments are wrong
}

// Assign arguments to variables for clarity
let password = CommandLine.arguments[1]
let login = CommandLine.arguments[2]
let socksPort = CommandLine.arguments[3]
let port = CommandLine.arguments[4]

// Create an instance of our handler, passing in the arguments
let connectionHandler = SSHConnectionHandler(
    sshPassword: password,
    sshLogin: login,
    localSocksPort: socksPort,
    sshPort: port
)

// Start the handler
connectionHandler.start()

// Keep the program alive
print("[INFO] Program started. Monitoring SSH connection. Press Ctrl+C in the console to exit.")
RunLoop.current.run()
