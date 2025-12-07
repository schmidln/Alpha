//
//  ActivityService.swift
//  Alpha
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class ActivityService: ObservableObject {
    @Published var activities: [Activity] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreActivities = true
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var userId: String?
    private var lastDocument: DocumentSnapshot?
    
    private let initialLoadCount = 10
    private let loadMoreCount = 20
    
    func configure(userId: String) {
        self.userId = userId
        startListening()
    }
    
    func startListening() {
        guard let userId = userId else {
            print("😡 ActivityService: No userId set")
            return
        }
        
        print("😎 ActivityService: Starting listener for userId: \(userId)")
        
        // Remove existing listener
        listener?.remove()
        isLoading = true
        activities = []
        lastDocument = nil
        hasMoreActivities = true
        
        // Listen to first batch of activities in real-time
        listener = db.collection("activities")
            .whereField("userId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .limit(to: initialLoadCount)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    print("😡 Activity listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                self.activities = documents.compactMap { doc in
                    try? doc.data(as: Activity.self)
                }
                
                self.lastDocument = documents.last
                self.hasMoreActivities = documents.count >= self.initialLoadCount
                
                print("😎 Loaded \(self.activities.count) activities")
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Load More (Pagination) - this is something I learned because I wanted the app to constantly update in the background inline with the firebase updates.
    // If you ever haves students that are confused about pagination in the future I would recommend the following sources:
    // https://firebase.google.com/docs/firestore/query-data/query-cursors
    // https://firebase.google.com/docs/reference/swift/firebasefirestore/api/reference/Classes/Query
    
    func loadMore() async {
        guard let userId = userId,
              let lastDoc = lastDocument,
              !isLoadingMore,
              hasMoreActivities else { return }
        
        isLoadingMore = true
        
        do {
            let snapshot = try await db.collection("activities")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: loadMoreCount)
                .getDocuments()
            
            let newActivities = snapshot.documents.compactMap { doc in
                try? doc.data(as: Activity.self)
            }
            
            self.activities.append(contentsOf: newActivities)
            self.lastDocument = snapshot.documents.last
            self.hasMoreActivities = snapshot.documents.count >= loadMoreCount
            
            print("😎 Loaded \(newActivities.count) more activities, total: \(self.activities.count)")
        } catch {
            print("😡 Load more error: \(error)")
        }
        
        isLoadingMore = false
    }
    
    // MARK: - Manual Refresh - even though the manual refresh was unnecessary because of the Pagination - I wanted to integrate this functionality because we learned it in class, and because I felt that users are accustomed to having a manual refresh. Therefore, even if the manual refresh does nothing, a user will appreciate having that illusion.
    
    func refresh() async {
        guard let userId = userId else { return }
        
        isLoading = true
        lastDocument = nil
        hasMoreActivities = true
        
        do {
            let snapshot = try await db.collection("activities")
                .whereField("userId", isEqualTo: userId)
                .order(by: "timestamp", descending: true)
                .limit(to: initialLoadCount)
                .getDocuments()
            
            self.activities = snapshot.documents.compactMap { doc in
                try? doc.data(as: Activity.self)
            }
            
            self.lastDocument = snapshot.documents.last
            self.hasMoreActivities = snapshot.documents.count >= initialLoadCount
            
            print("😎 Refreshed \(self.activities.count) activities")
        } catch {
            print("😡 Refresh error: \(error)")
        }
        
        isLoading = false
    }
    
    deinit {
        listener?.remove()
    }
}
