import SwiftUI
import Speech
import AVFoundation

struct SpeechTestView: View {
    @State private var isRecording = false
    @State private var recognizedText = ""
    @State private var statusMessage = "点击麦克风开始录音"
    @State private var authorizationStatus = SFSpeechRecognizerAuthorizationStatus.notDetermined

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer? { SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")) }
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?

    var body: some View {
        VStack(spacing: DSSpacing.md) {
            Text("语音测试")
                .dsTextStyle(.headline)
                .foregroundColor(.white)

            // Status
            Text(statusMessage)
                .dsTextStyle(.caption1)
                .foregroundColor(.white.opacity(0.7))

            // Recognized text
            ScrollView {
                Text(recognizedText.isEmpty ? "识别结果将显示在这里..." : recognizedText)
                    .dsTextStyle(.body)
                    .foregroundColor(recognizedText.isEmpty ? .white.opacity(0.4) : .white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(DSSpacing.sm)
            }
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: DSCornerRadius.small)
                    .fill(Color.white.opacity(0.1))
            )

            HStack(spacing: DSSpacing.md) {
                // Record / Stop
                Button(action: { isRecording ? stopRecording() : startRecording() }) {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 16))
                        Text(isRecording ? "停止" : "录音")
                            .dsTextStyle(.caption1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.small)
                            .fill(isRecording ? Color.red.opacity(0.7) : Color.dsPrimary)
                    )
                }

                // TTS test
                Button(action: { speak(recognizedText) }) {
                    HStack(spacing: DSSpacing.xxs) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16))
                        Text("朗读")
                            .dsTextStyle(.caption1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DSCornerRadius.small)
                            .fill(Color.dsSecondary)
                    )
                }
                .disabled(recognizedText.isEmpty)
                .opacity(recognizedText.isEmpty ? 0.5 : 1)

                // Clear
                Button(action: { recognizedText = "" }) {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding(DSSpacing.md)
        .background(Color.dsBackground)
        .onAppear { checkAuthorization() }
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        SFSpeechRecognizer.requestAuthorization { status in
            authorizationStatus = status
        }
        // Also log whether the recognizer hardware is available
        if let r = recognizer {
            let available = r.isAvailable
            if !available, authorizationStatus == .authorized {
                statusMessage = "Siri 与听写已被禁用，请在设置中开启"
            }
        }
    }

    // MARK: - Recording

    private func startRecording() {
        guard authorizationStatus == .authorized else {
            statusMessage = "未授权语音识别，请在设置中开启"
            return
        }

        guard let r = recognizer else {
            statusMessage = "当前语言不支持语音识别"
            return
        }

        guard r.isAvailable else {
            statusMessage = "Siri 与听写已被禁用，请在设置中开启"
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = r.supportsOnDeviceRecognition

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        r.recognitionTask(with: request) { result, error in
            if let error {
                statusMessage = "识别错误: \(error.localizedDescription)"
                return
            }
            if let result = result {
                recognizedText = result.bestTranscription.formattedString
                statusMessage = result.isFinal ? "识别完成" : "识别中..."
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            statusMessage = "识别中..."
        } catch {
            statusMessage = "无法启动录音: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isRecording = false
        statusMessage = "已停止"
    }

    // MARK: - TTS

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
        utterance.rate = 0.5
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}
