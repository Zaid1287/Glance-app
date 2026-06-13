#if canImport(MultipeerConnectivity)
import Foundation
import MultipeerConnectivity

/// Service type must be 1–15 chars, lowercase letters/digits/hyphens (Bonjour rule).
private let glanceServiceType = "glance-sync"

/// The spec's LAN fast-path. Same `OutboundTransport`/`InboundTransport` seam as
/// the TCP stand-in, so the publisher/subscriber/detectors/UI are unchanged —
/// only which transport you construct differs.
///
/// Frames stay wrapped in `SecureCodec`: a peer can join at the MultipeerConnectivity
/// layer, but without the pairing key it cannot decrypt anything (defense in depth
/// over MPC's own `.required` link encryption, and shared with the relay path).
/// MPC is message-framed, so the codec's trailing newline is stripped on receipt.

/// Agent side: advertises on the LAN and broadcasts encrypted task updates.
public final class MultipeerAdvertiser: NSObject, OutboundTransport {
    private let session: MCSession
    private let advertiser: MCNearbyServiceAdvertiser
    private let codec: SecureCodec

    /// Tasks to replay to a peer the instant it connects, so a phone that
    /// (re)connects catches up to the true state — including a task that finished
    /// while it was away (fixes a Live Activity stuck mid-progress).
    public var snapshotProvider: (() -> [TrackedTask])?

    public init(displayName: String, codec: SecureCodec) {
        let peerID = MCPeerID(displayName: String(displayName.prefix(63)))
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: glanceServiceType)
        self.codec = codec
        super.init()
        session.delegate = self
        advertiser.delegate = self
    }

    public func start() { advertiser.startAdvertisingPeer() }
    public func stop() { advertiser.stopAdvertisingPeer(); session.disconnect() }

    public func send(_ envelope: TaskEnvelope) {
        let peers = session.connectedPeers
        guard !peers.isEmpty else { return }
        let data = codec.seal(envelope)
        guard !data.isEmpty else { return }
        try? session.send(data, toPeers: peers, with: .reliable)
    }
}

extension MultipeerAdvertiser: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                           didReceiveInvitationFromPeer peerID: MCPeerID,
                           withContext context: Data?,
                           invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // The shared pairing key is the real gate; admit the peer to the session.
        invitationHandler(true, session)
    }
}

/// Subscriber side (phone/iPad/Mac): browses for the agent and surfaces decrypted frames.
public final class MultipeerBrowser: NSObject, InboundTransport {
    public var onReceive: ((TaskEnvelope) -> Void)?
    private let session: MCSession
    private let browser: MCNearbyServiceBrowser
    private let codec: SecureCodec

    public init(displayName: String, codec: SecureCodec) {
        let peerID = MCPeerID(displayName: String(displayName.prefix(63)))
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: glanceServiceType)
        self.codec = codec
        super.init()
        session.delegate = self
        browser.delegate = self
    }

    public func start() { browser.startBrowsingForPeers() }
    public func stop() { browser.stopBrowsingForPeers(); session.disconnect() }
}

extension MultipeerBrowser: MCNearbyServiceBrowserDelegate {
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                        withDiscoveryInfo info: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 15)
    }
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

extension MultipeerBrowser: MCSessionDelegate {
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        var frame = data
        if frame.last == 0x0A { frame.removeLast() }
        if let env = codec.open(frame) { onReceive?(env) }
    }
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {}
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// Advertiser needs a session delegate too (it doesn't consume inbound data).
extension MultipeerAdvertiser: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state == .connected, let tasks = snapshotProvider?() else { return }
        for task in tasks {
            let data = codec.seal(.update(task))
            if !data.isEmpty { try? session.send(data, toPeers: [peerID], with: .reliable) }
        }
    }
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
#endif
