//
//  PermissionsService.swift
//  Alpha
//

import Foundation
import Combine
import Contacts
import UserNotifications
import CoreLocation
import Speech
import AVFAudio

@MainActor
class PermissionsService: NSObject, ObservableObject {
    @Published var contactsGranted = false
    @Published var notificationsGranted = false
    @Published var locationGranted = false
    @Published var microphoneGranted = false
    @Published var speechRecognitionGranted = false
    
    @Published var allPermissionsHandled = false
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        checkAllPermissions()
    }
    
    // MARK: - Check All
    
    func checkAllPermissions() {
        checkContactsPermission()
        checkNotificationsPermission()
        checkLocationPermission()
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        updateAllPermissionsStatus()
    }
    
    private func updateAllPermissionsStatus() {
        // Minimum required permissions: contacts, notifications
        allPermissionsHandled = contactsGranted && notificationsGranted
    }
    
    // MARK: - Contacts
    
    func checkContactsPermission() {
        contactsGranted = CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }
    
    func requestContactsPermission() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactsGranted = granted
            updateAllPermissionsStatus()
            return granted
        } catch {
            return false
        }
    }
    
    // MARK: - Notifications
    
    func checkNotificationsPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            notificationsGranted = settings.authorizationStatus == .authorized
            updateAllPermissionsStatus()
        }
    }
    
    func requestNotificationsPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            notificationsGranted = granted
            updateAllPermissionsStatus()
            return granted
        } catch {
            return false
        }
    }
    
    // MARK: - Location
    
    func checkLocationPermission() {
        let status = locationManager.authorizationStatus
        locationGranted = status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    // MARK: - Microphone

    func checkMicrophonePermission() {
        microphoneGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                Task { @MainActor in
                    self.microphoneGranted = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Speech Recognition
    
    func checkSpeechRecognitionPermission() {
        speechRecognitionGranted = SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.speechRecognitionGranted = status == .authorized
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionsService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationPermission()
        updateAllPermissionsStatus()
    }
}
