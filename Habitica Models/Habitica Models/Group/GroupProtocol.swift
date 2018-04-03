//
//  GroupProtocol.swift
//  Habitica Models
//
//  Created by Phillip Thelen on 29.03.18.
//  Copyright © 2018 HabitRPG Inc. All rights reserved.
//

import Foundation

public protocol GroupProtocol {
    var id: String? { get set }
    var name: String? { get set }
    var groupDescription: String? { get set }
    var summary: String? { get set }
    var type: String? { get set }
    var memberCount: Int { get set }
    var privacy: String? { get set }
    var balance: Float { get set }
    var quest: QuestStateProtocol? { get set }
    var chat: [ChatMessageProtocol] { get set }
}