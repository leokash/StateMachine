//
//  main.swift
//  StateMachine
//
//  Created by Nkashama Kabeya on 01/10/2023.
//

import Foundation

protocol Event: Hashable {}
protocol State: Hashable {}

enum States: State {
    case gas, solid, liquid, plasma
}

enum Action: Event {
    case boil, melt, freeze, condensate, sublimate, deposit, ionize, deionize
}

// MARK: - Vanilla State Machine

var machine1 = Vanilla.StateMachine<States, Action>(with: .liquid)

machine1.addTransition(from: .solid, to: .liquid, for: .melt) { print("melting... State changed to [LIQUID]") }
machine1.addTransition(from: .solid, to: .gas, for: .sublimate) { print("sublamating... State changed to [GAS]") }

machine1.addTransition(from: .gas, to: .solid, for: .deposit) { print("depositing... State changed to [SOLID]") }
machine1.addTransition(from: .gas, to: .liquid, for: .condensate) { print("condensating... State changed to [LIQUID]") }

machine1.addTransition(from: .liquid, to: .gas, for: .boil) { print("boiling... State changed to [GAS]") }
machine1.addTransition(from: .liquid, to: .solid, for: .freeze) { print("freezing... State changed to [SOLID]") }

machine1.addTransition(from: .gas, to: .plasma, for: .ionize) { print("ionizing... State changed to [PLASMA]") }
machine1.addTransition(from: .plasma, to: .gas, for: .deionize) { print("de-ionizing... State changed to [GAS]") }

print("Vanilla Machine")

machine1.on(event: .ionize)
machine1.on(event: .freeze)
machine1.on(event: .sublimate)
machine1.on(event: .ionize)
machine1.on(event: .freeze)
machine1.on(event: .boil)
machine1.on(event: .deionize)
machine1.on(event: .condensate)
machine1.on(event: .boil)
machine1.on(event: .deposit)
machine1.on(event: .melt)

print("")

// MARK: - DSL State Machine

struct MatterTransition: DefaultTransition {
    typealias E = Action
    typealias S = States
    
    let event: Action
    let incoming: States
    let outgoing: States
    let onTransitioned: (any State) -> ()
    
    init(event: Action, from: States, to: States, completion: @escaping (any State) -> ()) {
        self.event = event
        self.incoming = from
        self.outgoing = to
        self.onTransitioned = completion
    }
    
    func process() -> any State {
        print("processing \(event) from \(incoming)")
        return outgoing
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(event)
        hasher.combine(incoming)
        hasher.combine(outgoing)
    }
    
    static func == (lhs: MatterTransition, rhs: MatterTransition) -> Bool {
        lhs.event == rhs.event
        && lhs.incoming == rhs.incoming
        && lhs.outgoing == rhs.outgoing
    }
}

class AsyncMatterTransition: AsyncTransition {
    typealias E = Action
    typealias S = States
    
    let wait: TimeInterval
    
    let event: Action
    let incoming: States
    let outgoing: States
    let onTransitioned: (any State) -> ()
    
    init(event: Action, from: States, to: States, waitTime: TimeInterval, completion: @escaping (any State) -> ()) {
        self.event = event
        self.incoming = from
        self.outgoing = to
        self.wait = waitTime
        self.onTransitioned = completion
    }
    
    private var cancelled = false
    
    func cancel() {
        cancelled = true
    }
    
    func process(_ completion: (any State) -> ()) {
        print("processing \(event) from \(incoming)")
        Thread.sleep(until: Date(timeIntervalSinceNow: wait))
        if cancelled {
            print("processing cancelled for \(event) from state: \(incoming)... elapsed time: \(wait) secs")
        }  else {
            print("still processing \(event) from state: \(incoming)... elapsed time: \(wait) secs")
            completion(outgoing)
        }
    }
    
    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(event)
        hasher.combine(incoming)
        hasher.combine(outgoing)
    }
    
    static func == (lhs: AsyncMatterTransition, rhs: AsyncMatterTransition) -> Bool {
        lhs.event == rhs.event
        && lhs.incoming == rhs.incoming
        && lhs.outgoing == rhs.outgoing
    }
}

var machine2 = StateMachine.machine(with: States.liquid) {
    MatterTransition(event: .melt, from: .solid, to: .liquid) { state in print("State changed to [\(state)]") }
    MatterTransition(event: .sublimate, from: .solid, to: .gas) { state in print("State changed to [\(state)]") }
    
    AsyncMatterTransition(event: .deposit, from: .gas, to: .solid, waitTime: 2) { state in print("State changed to [\(state)]") }
    AsyncMatterTransition(event: .condensate, from: .gas, to: .liquid, waitTime: 8) { state in print("State changed to [\(state)]") }
    
    AsyncMatterTransition(event: .boil, from: .liquid, to: .gas, waitTime: 2) { state in print("State changed to [\(state)]") }
    MatterTransition(event: .freeze, from: .liquid, to: .solid) { state in print("State changed to [\(state)]") }
    
    MatterTransition(event: .ionize, from: .gas, to: .plasma) { state in print("State changed to [\(state)]") }
    MatterTransition(event: .deionize, from: .plasma, to: .gas) { state in print("State changed to [\(state)]") }
}

print("DSL Machine")

machine2.handle(event: Action.ionize)
machine2.handle(event: Action.freeze)
machine2.handle(event: Action.sublimate)
machine2.handle(event: Action.ionize)
machine2.handle(event: Action.freeze)
machine2.handle(event: Action.boil)
machine2.handle(event: Action.deionize)
machine2.handle(event: Action.condensate)
machine2.handle(event: Action.boil)
machine2.handle(event: Action.deposit)
machine2.handle(event: Action.melt)

RunLoop.main.run()
