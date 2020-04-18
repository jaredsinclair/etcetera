//
//  GlobalTests.swift
//  EtceteraTests
//
//  Created by Jared Sinclair on 01/24/20.
//  Copyright © 2020 Nice Boy LLC. All rights reserved.
//

import XCTest
import Etcetera

class GlobalTests: XCTestCase {

    func testTheBasics() {
        let object = MyClass()
        XCTAssertEqual(object.colorProvider.accentColor, .blue)
        XCTAssertEqual(object.postsProvider.fetchSomething(), "Posts")
        XCTAssertEqual(object.usersProvider.fetchSomething(), "Users")
        XCTAssertEqual(object.roomsProvider.fetchSomething(), "Rooms")
    }

    func testThatRecursiveResolutionDoesntDeadlock() {
        struct SomethingNeedsAnimal {
            @Global() var animal: Animal
        }
        _ = SomethingNeedsAnimal()
    }

}

// MARK: -

protocol ColorProviding {
    var accentColor: UIColor { get }
}

struct ProductionColorProvider: ColorProviding {
    var accentColor: UIColor { .red }
}

struct TestColorProvider: ColorProviding {
    var accentColor: UIColor { .blue }
}

extension Global where Wrapped == ColorProviding {
    init() {
        self.init { container in
            switch container.context {
            case .unitTesting, .userInterfaceTesting:
                return TestColorProvider()
            case .running, .custom:
                return ProductionColorProvider()
            }
        }
    }
}

// MARK: -

protocol WebServiceProviding {
    func fetchSomething() -> String
}

enum Microservice: String {
    case users
    case posts
    case rooms
}

class UsersService: WebServiceProviding {
    func fetchSomething() -> String { "Users" }
}

class PostsService: WebServiceProviding {
    func fetchSomething() -> String { "Posts" }
}

class RoomsService: WebServiceProviding {
    func fetchSomething() -> String { "Rooms" }
}

extension Global where Wrapped == WebServiceProviding {
    init(_ microservice: Microservice) {
        self.init(instanceIdentifier: microservice) { _ in
            switch microservice {
            case .posts: return PostsService()
            case .users: return UsersService()
            case .rooms: return RoomsService()
            }
        }
    }
}

// MARK: -

struct Water: GloballyAvailable {
    static func make(container: Container) -> Self {
        Water()
    }
}

struct Plant: GloballyAvailable {
    let water: Water

    static func make(container: Container) -> Self {
        Plant(water: container.resolveInstance())
    }
}

struct Animal: GloballyAvailable {
    let water: Water
    let plant: Plant

    static func make(container: Container) -> Animal {
        Animal(water: container.resolveInstance(), plant: container.resolveInstance())
    }
}

// MARK: -

class MyClass {
    @Global() var colorProvider: ColorProviding
    @Global(.posts) var postsProvider: WebServiceProviding
    @Global(.users) var usersProvider: WebServiceProviding
    @Global(.rooms) var roomsProvider: WebServiceProviding
}
