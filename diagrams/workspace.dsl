/*
 * Citizen Services Portal - C4 model (Structurizr DSL)
 * C4 Level 1 - System Context: who uses the portal, and which external systems does it depend on or serve?
 * Edit online: paste into https://structurizr.com/dsl
 * Export SVG:  structurizr-cli export -workspace diagrams/workspace.dsl -format plantuml -output <tmp>
 *              plantuml -tsvg <tmp>/structurizr-c4_system_context.puml, then copy to diagrams/c4_system_context.svg
 */
workspace "Citizen Services Portal" "Architecture model of the Citizen Services Portal." {

    !identifiers hierarchical

    model {
        resident = person "Resident / Citizen" "Finds, requests and tracks public services; exchanges documents and messages; signs documents; sees who accessed their data. May act as a delegate for another person within a given scope."
        admin = person "Administrator / Helpdesk" "Supports residents and operates the portal with role-limited access to case data."
        auditor = person "Auditor / Oversight body" "Verifies that citizen data was accessed and processed lawfully."
        ops = person "Operations / Security team" "Monitors service health and responds to incidents and security events."
        agencyStaff = person "Agency staff" "Processes requests for their own organization's services." "External"

        portal = softwareSystem "Citizen Services Portal" "Single digital entry point for public services: service catalogue, case management, document exchange, signing workflow, notifications, delegation, audit and transparency, regulated public APIs."

        idp = softwareSystem "National eID / OIDC identity provider" "Authenticates residents. The portal trusts only configured providers and validates every token." "External"
        signing = softwareSystem "Digital signing service" "Creates and validates legally binding eID signatures." "External"
        agencies = softwareSystem "Agency back-end e-services" "Systems of the agencies that deliver and decide the services. Separate trust domain." "External"
        registries = softwareSystem "External registries" "Authoritative data such as population, business and mandate/delegation registries." "External"
        thirdParty = softwareSystem "Third-party service providers" "Consume the portal's regulated public APIs as registered clients." "External"
        notify = softwareSystem "Notification providers" "Deliver email, SMS and push messages." "External"

        // Each relationship has its own colour tag (r1..r12); the label text matches its line.
        resident -> portal "Uses services, tracks requests, signs documents" "" "r1"
        admin -> portal "Supports residents, administers portal" "" "r2"
        auditor -> portal "Reviews audit evidence (read-only)" "" "r3"
        ops -> portal "Monitors health and security events" "" "r4"

        portal -> idp "Authenticates residents via" "" "r5"
        portal -> signing "Signs and validates documents via" "" "r6"
        portal -> agencies "Sends requests; gets status and decisions" "" "r7"
        portal -> registries "Looks up data, verifies delegations" "" "r8"
        thirdParty -> portal "Calls regulated public APIs" "" "r9"
        portal -> notify "Sends notifications via" "" "r10"
        notify -> resident "Delivers email, SMS, push to" "" "r11"
        agencyStaff -> agencies "Processes cases in" "" "r12"
    }

    views {
        systemContext portal "c4_system_context" {
            title "System Context - Citizen Services Portal"
            include *
            include agencyStaff
            autoLayout tb 250 200
        }

        styles {
            element "Element" {
                color #ffffff
                metadata false
            }
            relationship "Relationship" {
                width 220
                fontSize 20
            }
            element "Person" {
                shape Person
                background #08427b
            }
            element "Software System" {
                background #1168bd
            }
            element "External" {
                background #999999
            }
            relationship "r1" {
                color #1f77b4
            }
            relationship "r2" {
                color #2ca02c
            }
            relationship "r3" {
                color #9467bd
            }
            relationship "r4" {
                color #8c564b
            }
            relationship "r5" {
                color #d62728
            }
            relationship "r6" {
                color #e377c2
            }
            relationship "r7" {
                color #ff7f0e
            }
            relationship "r8" {
                color #17becf
            }
            relationship "r9" {
                color #7f7f7f
            }
            relationship "r10" {
                color #bcbd22
            }
            relationship "r11" {
                color #393b79
            }
            relationship "r12" {
                color #637939
            }
        }
    }

}
