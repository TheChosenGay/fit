//
//  pose_detect_service.swift
//  fit
//
//  Created by dai shan on 2026/5/9.
//

import Foundation
import UIKit
// MARK: - PosePoint
struct PosePoint {
    let joint: String
    let location: CGPoint   // 归一化坐标 (0-1)
    let confidence: Float
}

typealias PosePoints = [PosePoint]

protocol PoseDetectService {
    // 检测图像中的人体姿势数据
    func detectPose(from image:UIImage) async throws -> PosePoints?
}
