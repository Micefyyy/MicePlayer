import AVFoundation

final class FairPlayManager: NSObject, AVAssetResourceLoaderDelegate {
    private let licenseURL: URL
    private let certificateURL: URL

    init(licenseURL: URL, certificateURL: URL) {
        self.licenseURL = licenseURL
        self.certificateURL = certificateURL
        super.init()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        guard let url = loadingRequest.request.url,
              url.scheme == "skd" else {
            return false
        }

        Task {
            await handleFairPlayRequest(loadingRequest)
        }
        return true
    }

    private func handleFairPlayRequest(_ loadingRequest: AVAssetResourceLoadingRequest) async {
        do {
            guard let spcData = try await loadingRequest.streamingContentKeyRequestData(
                forApp: certificateData(),
                contentIdentifier: contentIdentifier(),
                options: nil
            ) else {
                loadingRequest.finishLoading(with: FairPlayError.noSPC)
                return
            }

            let ckcData = try await requestLicense(spc: spcData)
            loadingRequest.dataRequest?.respond(with: ckcData)
            loadingRequest.finishLoading()
        } catch {
            loadingRequest.finishLoading(with: error)
        }
    }

    private func certificateData() -> Data {
        guard let url = Bundle.main.url(forResource: "fairplay_cert", withExtension: "der"),
              let data = try? Data(contentsOf: url) else {
            return Data()
        }
        return data
    }

    private func contentIdentifier() -> Data {
        Data()
    }

    private func requestLicense(spc: Data) async throws -> Data {
        var request = URLRequest(url: licenseURL)
        request.httpMethod = "POST"
        request.httpBody = spc
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw FairPlayError.licenseDenied
        }
        return data
    }
}

enum FairPlayError: LocalizedError {
    case noSPC
    case licenseDenied
    case noCertificate

    var errorDescription: String? {
        switch self {
        case .noSPC: return "Failed to generate SPC"
        case .licenseDenied: return "License server denied request"
        case .noCertificate: return "FairPlay certificate not found"
        }
    }
}
