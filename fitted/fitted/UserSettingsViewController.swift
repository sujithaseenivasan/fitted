//  SettingsViewController.swift
//  fitted
//
//  Drop this in one file. Requires:
//  - FirebaseAuth
//  - FirebaseFirestore
//  - FirebaseStorage
//  - iOS 14+ (PHPicker)
//  Storyboard: VC with a UITableView, prototype cell "SettingsCell" (Right Detail)

import UIKit
import PhotosUI
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

// MARK: - Model

struct Profile {
    var fullName: String = ""
    var username: String = ""
    var email: String = ""
    var venmo: String = ""
    var phone: String = ""
    var notificationsOn: Bool = true
    var profilePictureURL: String? = nil
}

enum EditableField: CaseIterable {
    case fullName, username, email, venmo, phone, password, notifications

    var title: String {
        switch self {
        case .fullName: return "Name"
        case .username: return "Username"
        case .email: return "Email"
        case .venmo: return "Venmo"
        case .phone: return "Phone number"
        case .password: return "Password"
        case .notifications: return "Notification Preference"
        }
    }
    var isToggle: Bool { self == .notifications }
    var isSecure: Bool { self == .password }
}

// MARK: - Controller

final class UserSettingsViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!

    private var profile = Profile()
    private let fields: [EditableField] = [.fullName, .username, .email, .venmo, .phone, .password, .notifications]

    // Header (avatar + button)
    private let headerContainer = UIView()
    private let avatarImageView = UIImageView()
    private let editPhotoButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Your Profile"

        tableView.dataSource = self
        tableView.delegate   = self
        tableView.tableFooterView = UIView()

        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell") // temp safety
            
        configureHeader()
        loadProfile()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("rows:", tableView.numberOfRows(inSection: 0))
        print("has header:", tableView.tableHeaderView != nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let header = tableView.tableHeaderView else { return }
        // Recompute height with the current table width
        let targetWidth = tableView.bounds.width
        let size = header.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if header.frame.size.height != size.height {
            header.frame.size.height = size.height
            tableView.tableHeaderView = header
        }
    }


    // MARK: Header UI
    private func configureHeader() {
        // Logo image (from Assets)
        let logoImageView = UIImageView(image: UIImage(named: "FittedLogo")) // replace with your actual asset name
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.heightAnchor.constraint(equalToConstant: 40).isActive = true

        // Avatar
        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        avatarImageView.image = UIImage(systemName: "person.crop.circle")
        avatarImageView.tintColor = .secondaryLabel
        NSLayoutConstraint.activate([
            avatarImageView.widthAnchor.constraint(equalToConstant: 120),
            avatarImageView.heightAnchor.constraint(equalToConstant: 120)
        ])

        // Make it circular after constraints
        avatarImageView.layer.cornerRadius = 60

        // Button
        editPhotoButton.setTitle("Edit profile photo", for: .normal)
        editPhotoButton.addTarget(self, action: #selector(editPhotoTapped), for: .touchUpInside)

        // Stack centers both
        let stack = UIStackView(arrangedSubviews: [avatarImageView, editPhotoButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        // Container only relates to its own subviews
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 24),
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16)
        ])

        // Host view used as tableHeaderView (no constraints to tableView!)
        let host = UIView()
        host.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            container.topAnchor.constraint(equalTo: host.topAnchor),
            container.bottomAnchor.constraint(equalTo: host.bottomAnchor)
        ])

        // Compute height using a target width (tableHeaderView ignores Auto Layout)
        let targetWidth = tableView.bounds.width
        let size = host.systemLayoutSizeFitting(
            CGSize(width: targetWidth, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        host.frame = CGRect(origin: .zero, size: size)

        tableView.tableHeaderView = host

        // Tap on avatar also opens picker
        avatarImageView.isUserInteractionEnabled = true
        avatarImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(editPhotoTapped)))
    }

    // MARK: Load profile

    private func loadProfile() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Firestore.firestore().collection("users").document(uid).getDocument { [weak self] snap, _ in
            guard let self = self, let data = snap?.data() else { return }

            let first = (data["firstName"] as? String ?? "").trimmingCharacters(in: .whitespaces)
            let last  = (data["lastName"]  as? String ?? "").trimmingCharacters(in: .whitespaces)
            self.profile.fullName = [first, last].filter { !$0.isEmpty }.joined(separator: " ")

            self.profile.username = data["username"] as? String ?? ""
            self.profile.email    = data["email"] as? String ?? ""
            self.profile.venmo    = data["venmo"] as? String ?? ""
            self.profile.phone    = data["phoneNumber"] as? String ?? ""
            self.profile.notificationsOn = data["notificationsOn"] as? Bool ?? true
            self.profile.profilePictureURL = data["profilePictureURL"] as? String

            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.loadAvatarFromURL()
            }
        }
    }

    private func loadAvatarFromURL() {
        guard let urlStr = profile.profilePictureURL, let url = URL(string: urlStr) else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let img = UIImage(data: data) else { return }
            DispatchQueue.main.async { self.avatarImageView.image = img }
        }.resume()
    }

    // MARK: Edit photo

    @objc private func editPhotoTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.selectionLimit = 1
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func uploadAvatar(_ image: UIImage) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // Center square & compress
        let square = centerSquare(image: image)
        guard let data = square.jpegData(compressionQuality: 0.85) else { return }

        DispatchQueue.main.async { self.avatarImageView.image = square }

        let ref = Storage.storage().reference().child("users/\(uid)/profile.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        ref.putData(data, metadata: metadata) { _, error in
            if let error = error { print("Upload error:", error.localizedDescription); return }
            ref.downloadURL { url, _ in
                guard let url = url else { return }
                Firestore.firestore().collection("users").document(uid)
                    .setData(["profilePictureURL": url.absoluteString], merge: true)
            }
        }
    }

    private func centerSquare(image: UIImage) -> UIImage {
        let side = min(image.size.width, image.size.height)
        let x = (image.size.width  - side) / 2.0
        let y = (image.size.height - side) / 2.0
        let rect = CGRect(x: x, y: y, width: side, height: side)
        guard let cg = image.cgImage?.cropping(to: rect) else { return image }
        let square = UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)

        // Optional downscale (bandwidth / memory)
        let target: CGFloat = 512
        if side <= target { return square }
        let ratio = target / side
        let newSize = CGSize(width: side * ratio, height: side * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, true, 1.0)
        square.draw(in: CGRect(origin: .zero, size: newSize))
        let scaled = UIGraphicsGetImageFromCurrentImageContext() ?? square
        UIGraphicsEndImageContext()
        return scaled
    }

    // MARK: Helpers

    private func value(for field: EditableField) -> String {
        switch field {
        case .fullName: return profile.fullName
        case .username: return profile.username.isEmpty ? "" : "@\(profile.username)"
        case .email:    return profile.email
        case .venmo:    return profile.venmo.isEmpty ? "" : "@\(profile.venmo)"
        case .phone:    return profile.phone
        case .password: return "••••••••"
        case .notifications: return profile.notificationsOn ? "On" : "Off"
        }
    }

    private func presentEditAlert(for field: EditableField) {
        let alert = UIAlertController(title: "Edit \(field.title)", message: nil, preferredStyle: .alert)
        if !field.isToggle {
            alert.addTextField { tf in
                tf.isSecureTextEntry = field.isSecure
                tf.autocapitalizationType = .none
                tf.keyboardType = (field == .phone) ? .phonePad : .default
                switch field {
                case .fullName: tf.text = self.profile.fullName
                case .username: tf.text = self.profile.username
                case .email:    tf.text = self.profile.email
                case .venmo:    tf.text = self.profile.venmo
                case .phone:    tf.text = self.profile.phone
                case .password: tf.text = ""
                case .notifications: break
                }
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .default, handler: { _ in
            let text = alert.textFields?.first?.text ?? ""
            self.applyEdit(field: field, value: text)
        }))
        present(alert, animated: true)
    }

    private func applyEdit(field: EditableField, value: String) {
        // Basic validation
        switch field {
        case .email where !value.contains("@"):
            hapticError(); return
        case .password where value.count < 8:
            hapticError(); return
        default: break
        }

        // Update local model
        switch field {
        case .fullName: profile.fullName = value
        case .username: profile.username = value
        case .email:    profile.email = value
        case .venmo:    profile.venmo = value
        case .phone:    profile.phone = value
        case .password: break
        case .notifications: break
        }

        // Persist
        save(field: field, value: value)
        tableView.reloadData()
        hapticSuccess()
    }

    @objc private func toggleNotifications(_ sw: UISwitch) {
        profile.notificationsOn = sw.isOn
        save(field: .notifications, value: sw.isOn ? "On" : "Off")
    }

    private func save(field: EditableField, value: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let users = Firestore.firestore().collection("users").document(uid)

        switch field {
        case .email:
            Auth.auth().currentUser?.updateEmail(to: value) { err in
                if let err = err { print("updateEmail error:", err.localizedDescription) }
            }
            users.setData(["email": value], merge: true)

        case .password:
            Auth.auth().currentUser?.updatePassword(to: value) { err in
                if let err = err { print("updatePassword error:", err.localizedDescription) }
            }

        case .fullName:
            let parts = value.split(separator: " ", maxSplits: 1).map(String.init)
            users.setData([
                "firstName": parts.first ?? "",
                "lastName": parts.count > 1 ? parts[1] : ""
            ], merge: true)

        case .username:
            users.setData(["username": value], merge: true)

        case .venmo:
            users.setData(["venmo": value], merge: true)

        case .phone:
            users.setData(["phoneNumber": value], merge: true)

        case .notifications:
            users.setData(["notificationsOn": (value == "On")], merge: true)
        }
    }

    private func hapticSuccess() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    private func hapticError() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}

// MARK: - TableView

extension UserSettingsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { fields.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let field = fields[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)

        // Configure title + trailing value using content configuration
        var config = UIListContentConfiguration.valueCell() // shows trailing secondary text
        config.text = field.title
        config.secondaryText = value(for: field)
        config.prefersSideBySideTextAndSecondaryText = true
        config.secondaryTextProperties.alignment = .justified
        cell.contentConfiguration = config

        // Accessory
        if field.isToggle {
            let sw = UISwitch()
            sw.isOn = profile.notificationsOn
            sw.addTarget(self, action: #selector(toggleNotifications(_:)), for: .valueChanged)
            cell.accessoryView = sw
            cell.selectionStyle = .none
        } else {
            cell.accessoryView = nil
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let field = fields[indexPath.row]
        guard !field.isToggle else { return }
        presentEditAlert(for: field)
    }
}


// MARK: - PHPicker

extension UserSettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        guard let provider = results.first?.itemProvider,
              provider.canLoadObject(ofClass: UIImage.self) else { return }

        provider.loadObject(ofClass: UIImage.self) { [weak self] object, _ in
            guard let self = self, let img = object as? UIImage else { return }
            self.uploadAvatar(img)
        }
    }
}
