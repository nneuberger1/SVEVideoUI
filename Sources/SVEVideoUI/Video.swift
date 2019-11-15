import SwiftUI
import AVFoundation
import AVKit

/// A view that displays an environment-dependent video.
///
/// The video element on iOS is a wrapper of the AVPLayerViewController, while on macOS is a wrapper
/// around AVPlayerView
/// It can be configured to display controls, auto-loop or mute sound depending of the developer needs.
///
/// - SeeAlso: `AVPLayerViewController`
public struct Video {

    /// The URL of the video you want to display
    var videoURL: URL

    /// If true the playback controler will be visible on the view
    var showsPlaybackControls: Bool = true

    /// If true the option to show the video in PIP mode will be available in the controls
    var allowsPictureInPicturePlayback:Bool = true

    /// If true the video sound will be muted
    var isMuted: Binding<Bool>

    /// How the video will resized to fit the view
    var videoGravity: AVLayerVideoGravity = .resizeAspect

    /// If true the video will loop itself when reaching the end of the video
    var loop: Bool = false

    /// if true the video will play itself automattically
    var isPlaying: Binding<Bool>

    public init(url: URL, playing: Binding<Bool> = .constant(true), muted: Binding<Bool> = .constant(false))
    {
        videoURL = url
        isPlaying = playing
        isMuted = muted
    }
}

#if os(iOS)
extension Video: UIViewControllerRepresentable {
    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let videoView = AVPlayerViewController()
        videoView.player = AVPlayer(url: videoURL)

        let videoCoordinator = context.coordinator
        videoCoordinator.player = videoView.player
        videoCoordinator.url = videoURL

        return videoView
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if videoURL != context.coordinator.url {
            uiViewController.player = AVPlayer(url: videoURL)
            context.coordinator.player = uiViewController.player
            context.coordinator.url = videoURL
        }
        uiViewController.showsPlaybackControls = showsPlaybackControls
        uiViewController.allowsPictureInPicturePlayback = allowsPictureInPicturePlayback
        uiViewController.player?.isMuted = isMuted.wrappedValue
        uiViewController.videoGravity = videoGravity
        context.coordinator.togglePlay(isPlaying: isPlaying.wrappedValue)
        context.coordinator.loop = loop
    }

    public func makeCoordinator() -> VideoCoordinator {
        return VideoCoordinator(video: self)
    }
}
#elseif os(macOS)
extension Video: NSViewRepresentable {

    public func makeNSView(context: Context) -> AVPlayerView {
        let videoView = AVPlayerView()
        videoView.player = AVPlayer(url: videoURL)

        let videoCoordinator = context.coordinator
        videoCoordinator.player = videoView.player
        videoCoordinator.url = videoURL

        return videoView
    }

    public func updateNSView(_ nsview: AVPlayerView, context: Context) {
        if videoURL != context.coordinator.url {
            nsview.player = AVPlayer(url: videoURL)
            context.coordinator.player = nsview.player
            context.coordinator.url = videoURL
        }
        if showsPlaybackControls {
            nsview.controlsStyle = .inline
        } else {
            nsview.controlsStyle = .none
        }
        if #available(OSX 10.15, *) {
            nsview.allowsPictureInPicturePlayback = allowsPictureInPicturePlayback
        } else {
            // Fallback on earlier versions
        }
        nsview.player?.isMuted = isMuted.wrappedValue
        nsview.videoGravity = videoGravity
        context.coordinator.togglePlay(isPlaying: isPlaying.wrappedValue)
        context.coordinator.loop = loop
    }

    public func makeCoordinator() -> VideoCoordinator {
        return VideoCoordinator(video: self)
    }
}
#endif

extension Video {
    // MARK: - Coordinator
    public class VideoCoordinator: NSObject {

        let video: Video

        var timeObserver: Any?

        var player: AVPlayer? {
            didSet {
                NotificationCenter.default.addObserver(self,
                                                       selector:#selector(Video.VideoCoordinator.playerItemDidReachEnd),
                                                       name:.AVPlayerItemDidPlayToEndTime,
                                                       object:player?.currentItem)

                timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 4), queue: nil, using: { [weak self](time) in
                    self?.updateStatus()
                })
            }
        }

        var loop: Bool = false

        var url: URL?

        init(video: Video){
            self.video = video
            super.init()
        }

        deinit {
            if let observer = timeObserver {
                player?.removeTimeObserver(observer)
            }
        }

        @objc public func playerItemDidReachEnd(notification: NSNotification) {
            if loop {
                player?.seek(to: .zero)
                player?.play()
            } else {
                video.isPlaying.wrappedValue = false
            }
        }

        @objc public func updateStatus() {
            if let player = player {
                video.isPlaying.wrappedValue = player.rate > 0
                video.isMuted.wrappedValue = player.isMuted
            } else {
                video.isPlaying.wrappedValue = false
                video.isMuted.wrappedValue = false
            }
        }

        func togglePlay(isPlaying: Bool) {
            if isPlaying {
                if player?.currentItem?.duration == player?.currentTime() {
                    player?.seek(to: .zero)
                    player?.play()
                }
                player?.play()
            } else {
                player?.pause()
            }
        }
    }
}
// MARK: - Modifiers
extension Video {

    public func pictureInPicturePlayback(_ value:Bool) -> Video {
        var new = self
        new.allowsPictureInPicturePlayback = value
        return new
    }

    public func playbackControls(_ value: Bool) ->Video {
        var new = self
        new.showsPlaybackControls = value
        return new
    }

    public func isMuted(_ value: Bool) -> Video {
        let new = self
        new.isMuted.wrappedValue = value
        return new
    }

    public func isMuted(_ value: Binding<Bool>) -> Video {
        var new = self
        new.isMuted = value
        return new
    }

    public func isPlaying(_ value: Bool) -> Video {
        let new = self
        new.isPlaying.wrappedValue = value
        return new
    }

    public func isPlaying(_ value: Binding<Bool>) -> Video {
        var new = self
        new.isPlaying = value
        return new
    }

    public func videoGravity(_ value: AVLayerVideoGravity) -> Video {
        var new = self
        new.videoGravity = value
        return new
    }

    public func loop(_ value: Bool) -> Video {
        var new = self
        new.loop = value
        return new
    }
}