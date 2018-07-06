//
//  MviViewModel.swift
//  MviKit
//
//  Created by Yohta Watanave on 2018/07/05.
//  Copyright © 2018年 Yohta Watanave. All rights reserved.
//

import Foundation
import RxSwift

public protocol MviViewModelProtocol {
    associatedtype Intent: MviIntent
    associatedtype State: MviState
    associatedtype Task: MviTask

    var state: Observable<State> { get }
    var task: Observable<Task> { get }
    func process(intents: Observable<Intent>)
}

open class MviViewModel<I, S, T, A, RR, DR>: MviViewModelProtocol where I: MviIntent, S: MviState, T: MviTask, A: MviAction, RR: MviRetentionResult, DR: MviDisposableResult {

    public typealias Intent = I
    public typealias State = S
    public typealias Task = T
    public typealias Action = A
    public typealias Result = MviResult<RR, DR>
    public typealias RetentionResult = RR
    public typealias DisposableResult = DR
    public typealias Processor = AnyProcessor<Action, RetentionResult, DisposableResult>

    private let intentsSubject = PublishSubject<Intent>()
    public let processor: Processor
    let disposeBag = DisposeBag()

    private lazy var result: Observable<Result> = {
        return intentsSubject
            .compose(self.intentFilter())
            .map(self.actionFrom)
            .flatMap(self.processor.process)
            .share()
    }()
    public lazy var state: Observable<State> = {
        let connectable = self.result
            .map { result -> RetentionResult? in
                switch result {
                case .retentionResult(let r): return r
                case .disposableResult: return nil
                }
            }
            .filter { $0 != nil }.map { $0! }
            .scan(State.default(), accumulator: self.reducer)
            .distinctUntilChanged()
            .replay(1)
        connectable.connect().disposed(by: self.disposeBag)
        return connectable
    }()
    public lazy var task: Observable<Task> = {
        let connectable = self.result
            .map { result -> DisposableResult? in
                switch result {
                case .retentionResult: return nil
                case .disposableResult(let d): return d
                }
            }
            .filter { $0 != nil }.map { $0! }
            .map(self.taskFrom)
            .publish()
        connectable.connect().disposed(by: self.disposeBag)
        return connectable
    }()

    // MARK: - Initializer
    public init(processor: Processor) {
        self.processor = processor
    }

    // MARK: - Public functions
    public func process(intents: Observable<Intent>) {
        _ = intents.subscribe(self.intentsSubject)
    }

    // MARK: -
    public func intentFilter() -> ComposeTransformer<Intent, Intent> {
        fatalError()
    }

    public func actionFrom(intent: Intent) -> Action {
        fatalError()
    }

    public func taskFrom(result: DisposableResult) -> Task {
        fatalError()
    }

    public func reducer(previousState: State, result: RetentionResult) -> State {
        fatalError()
    }
}

public final class AnyViewModel<I, S, T>: MviViewModelProtocol where I: MviIntent, S: MviState, T: MviTask {

    public typealias Intent = I
    public typealias State = S
    public typealias Task = T

    public let state: Observable<State>
    public let task: Observable<Task>
    private let _processIntent: (Observable<Intent>)->Void

    public init<Impl: MviViewModelProtocol>(_ impl: Impl) where Impl.Intent == I, Impl.State == S, Impl.Task == T {
        self.state = impl.state
        self.task = impl.task
        self._processIntent = impl.process
    }

    public func process(intents: Observable<Intent>) {
        self._processIntent(intents)
    }
}
