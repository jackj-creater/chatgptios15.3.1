import UIKit
import WebKit

final class ViewController: UIViewController {
    private enum Constants {
        static let homeURL = URL(string: "https://chatgpt.com/")!

        // Keep authentication redirects in the same persistent WKWebView. Links to
        // unrelated sites are handed to Safari instead.
        static let inAppDomains = [
            "chatgpt.com",
            "openai.com",
            "auth0.com",
            "google.com",
            "googleusercontent.com",
            "microsoftonline.com",
            "live.com",
            "apple.com",
            "icloud.com",
            "cloudflare.com",
            "oaiusercontent.com"
        ]
    }

    private lazy var webView: WKWebView = makeWebView()
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let errorView = UIView()
    private let errorLabel = UILabel()
    private var progressObservation: NSKeyValueObservation?
    private var downloadDestination: URL?
    private weak var popupWebView: WKWebView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        configureInterface()
        observeProgress()
        loadHome()
    }

    deinit {
        progressObservation?.invalidate()
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // The default data store is persistent. Cookies and website storage survive
        // normal app restarts; this app never clears them automatically.
        configuration.websiteDataStore = .default()
        configuration.allowsInlineMediaPlayback = true

        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        preferences.preferredContentMode = .mobile
        configuration.defaultWebpagePreferences = preferences
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        // WKWebView's engine remains the device's iOS 15 WebKit. Adding Safari's
        // product token helps sites that reject the bare embedded-browser UA without
        // falsely claiming to be Safari 17 or enabling unavailable WebKit features.
        configuration.applicationNameForUserAgent = "Version/15.0 Safari/604.1"

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        webView.scrollView.backgroundColor = .systemBackground
        return webView
    }

    private func configureInterface() {
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.isHidden = true

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.hidesWhenStopped = true

        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = .systemBackground
        errorView.isHidden = true

        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.textColor = .secondaryLabel

        let retryButton = UIButton(type: .system)
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.setTitle("Retry", for: .normal)
        retryButton.addTarget(self, action: #selector(retryLoad), for: .touchUpInside)

        view.addSubview(webView)
        view.addSubview(progressView)
        view.addSubview(activityIndicator)
        view.addSubview(errorView)
        errorView.addSubview(errorLabel)
        errorView.addSubview(retryButton)

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            progressView.topAnchor.constraint(equalTo: webView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorView.topAnchor.constraint(equalTo: webView.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorLabel.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            errorLabel.centerYAnchor.constraint(equalTo: errorView.centerYAnchor, constant: -24),
            errorLabel.leadingAnchor.constraint(greaterThanOrEqualTo: errorView.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(lessThanOrEqualTo: errorView.trailingAnchor, constant: -32),

            retryButton.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 16),
            retryButton.centerXAnchor.constraint(equalTo: errorView.centerXAnchor)
        ])
    }

    private func observeProgress() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            DispatchQueue.main.async {
                self?.progressView.progress = Float(webView.estimatedProgress)
                self?.progressView.isHidden = webView.estimatedProgress >= 1
            }
        }
    }

    private func loadHome() {
        errorView.isHidden = true
        let request = URLRequest(
            url: Constants.homeURL,
            cachePolicy: .useProtocolCachePolicy,
            timeoutInterval: 60
        )
        webView.load(request)
    }

    @objc private func retryLoad() {
        if webView.url == nil {
            loadHome()
        } else {
            errorView.isHidden = true
            webView.reload()
        }
    }

    private func showNavigationError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }

        activityIndicator.stopAnimating()
        errorLabel.text = "ChatGPT could not be loaded.\n\n\(error.localizedDescription)"
        errorView.isHidden = false
    }

    private func isInAppURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return Constants.inAppDomains.contains { domain in
            host == domain || host.hasSuffix("." + domain)
        }
    }

    private func openOutsideApp(_ url: URL) {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    private func temporaryDownloadURL(for suggestedFilename: String) -> URL? {
        let filename = URL(fileURLWithPath: suggestedFilename).lastPathComponent
        let safeFilename = filename.isEmpty ? "download" : filename
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ChatGPTLiteDownloads", isDirectory: true)

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            var destination = directory.appendingPathComponent(safeFilename)
            if FileManager.default.fileExists(atPath: destination.path) {
                destination = directory.appendingPathComponent(
                    UUID().uuidString + "-" + safeFilename
                )
            }
            return destination
        } catch {
            return nil
        }
    }

    private func showDownloadError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            let alert = UIAlertController(
                title: "Download failed",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }
}

extension ViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel, preferences)
            return
        }

        let scheme = url.scheme?.lowercased()
        if scheme == "about" && navigationAction.targetFrame == nil {
            decisionHandler(.allow, preferences)
            return
        }

        guard scheme == "http" || scheme == "https" else {
            openOutsideApp(url)
            decisionHandler(.cancel, preferences)
            return
        }

        if navigationAction.shouldPerformDownload {
            decisionHandler(.download, preferences)
            return
        }

        if navigationAction.targetFrame == nil {
            if isInAppURL(url) {
                decisionHandler(.allow, preferences)
            } else {
                openOutsideApp(url)
                decisionHandler(.cancel, preferences)
            }
            return
        }

        if navigationAction.navigationType == .linkActivated && !isInAppURL(url) {
            openOutsideApp(url)
            decisionHandler(.cancel, preferences)
            return
        }

        decisionHandler(.allow, preferences)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        let httpResponse = navigationResponse.response as? HTTPURLResponse
        let disposition = httpResponse?.value(forHTTPHeaderField: "Content-Disposition")?.lowercased()
        if disposition?.contains("attachment") == true || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        activityIndicator.startAnimating()
        progressView.isHidden = false
        errorView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        activityIndicator.stopAnimating()
        progressView.isHidden = true
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        showNavigationError(error)
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        showNavigationError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }
}

extension ViewController: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }

        popupWebView?.removeFromSuperview()

        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.allowsBackForwardNavigationGestures = true
        popup.isOpaque = false
        popup.backgroundColor = .systemBackground
        view.addSubview(popup)

        NSLayoutConstraint.activate([
            popup.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            popup.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            popup.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            popup.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        popupWebView = popup
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        if webView === popupWebView {
            popupWebView?.removeFromSuperview()
            popupWebView = nil
        }
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { textField in textField.text = defaultText }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}

extension ViewController: WKDownloadDelegate {
    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let destination = temporaryDownloadURL(for: suggestedFilename)
        downloadDestination = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination = downloadDestination else { return }
        downloadDestination = nil

        DispatchQueue.main.async { [weak self] in
            let picker = UIDocumentPickerViewController(
                forExporting: [destination],
                asCopy: true
            )
            self?.present(picker, animated: true)
        }
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestination = nil
        showDownloadError(error)
    }
}
