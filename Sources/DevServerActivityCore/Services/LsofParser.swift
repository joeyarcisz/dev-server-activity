import Foundation

public struct LsofParser: Sendable {
    public init() {}

    public func parseListeningRecords(_ output: String) -> [ListeningPortRecord] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private func parseLine(_ line: String) -> ListeningPortRecord? {
        let columns = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard
            columns.count >= 10,
            columns[0] != "COMMAND",
            let pid = Int(columns[1]),
            pid > 0
        else {
            return nil
        }

        let addressToken: String
        if columns.last == "(LISTEN)", columns.count >= 2 {
            addressToken = columns[columns.count - 2]
        } else if let last = columns.last {
            addressToken = last
        } else {
            return nil
        }

        guard let separator = addressToken.lastIndex(of: ":") else {
            return nil
        }

        let host = String(addressToken[..<separator])
        let portText = String(addressToken[addressToken.index(after: separator)...])
        guard let port = Int(portText), (1...65_535).contains(port) else {
            return nil
        }

        return ListeningPortRecord(pid: pid, command: columns[0], host: host, port: port)
    }
}
