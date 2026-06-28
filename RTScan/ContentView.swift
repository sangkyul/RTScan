import SwiftUI

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()

    var body: some View {
        ZStack(alignment: .top) {
            if cameraManager.isAuthorized {
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.white)
                    Text("Camera access is required to scan show thumbnails.")
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }

            VStack {
                Spacer()
                if let match = cameraManager.currentMatch {
                    ScorePopupView(match: match) {
                        cameraManager.dismissCurrentMatch()
                    }
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: cameraManager.currentMatch)
        }
        .onAppear {
            cameraManager.requestAccessAndStart()
        }
        .onDisappear {
            cameraManager.stop()
        }
    }
}

#Preview {
    ContentView()
}
