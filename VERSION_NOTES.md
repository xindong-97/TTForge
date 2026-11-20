# TTForge v7.31（房间测试移植版）

2026-11-20，用户令：独立插件 TTRoomTest 做的有问题，把 7 项房间功能移植进之前的 TT 功能插件（TTForge）。本版以 v7.30_build-2 正本（TTForge.m 5872 行，md5 edc3aed3be4b77029eb0a0b65f79e432）为底，只做新增，不动原有功能。独立版 TTRoomTest v1/v2 作废。

## 新增（+266 行，6138 行，md5 d86f22fad729fd8247bc6e3492764295）
- 面板新增「房间测试」一节：防闭麦、防清屏、192k音质、皮肤DressId、防踢、万能上麦、灵动岛记录 7 个开关（默认关，NSUserDefaults 持久化 ttforge.rt*）+「皮肤DressId值」输入行（0=只记录）。
- Hook 点与独立版 v2 完全一致（32 个，TT 6.89.0 真机已验全命中无 MISS）：防闭麦 4 参真实现 onMuteMicAction:tipsInView:muteToast:unmuteToast: + shouldIgnoreMuteMic:；防清屏 clearChannelMessageData 系列 + jsUi_clearChatBoxChannel:callback:（jsUi 版开时返回 nil 不调 callback，沿用独立版取舍）；192k updateAudioBitRate:（NSNumber 时替换 192000，测试猜测待日志校准）+ onChannelId:audioBitRateChanged:；皮肤 onRoomSuitDressIdUpdatedTo:（面板 DressId 非 0 时替换，与 TTForge 原有房间装扮 gRoomDressId 是两个点，日志前缀 ROOMTEST 区分）；防踢 onChannelMsgKicked:/onChannelMsgKickedMic:/onChannelMsgPushTimeOutKickedSelf:/onMicKicked:；万能上麦 supportChangemic:tip:（9 类）+ supportChangemic:tip:callback:（2 类）+ isCanChangeMeToMic:isMeOnMic:reason:callback:（5 类）；灵动岛 getChannelLiveActivityContainerView + registerLiveActivity 只记录。
- 实现按 TTForge 规矩：MRC、TTLog 写 TTForgeLog/ttforge.log（不再有独立版的面板日志竞态）、TTRTSwizzle 用 class_addMethod 优先、原 IMP 按类+方法存字典、启动 2 秒后主队列装 Hook、启动日志升 v7.31。新增代码无注释。
- 自审：diff 对 v7.30 正本只有新增行 + 启动日志版本号一行；TTForge 原有 Hook 与新增 32 个无重叠（原文件 grep 无这些 selector）；类名/方法名/类型编码逐字核对类表（独立版已验）。
- 未编译、未真机（本 VM 无 iOS SDK）。编不编、走哪条 CI 线由用户定，TTForge 原规矩（状态同步、无明确开口不编译不推仓）继续有效。
