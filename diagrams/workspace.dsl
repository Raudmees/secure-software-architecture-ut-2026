/*
 * Citizen Services Portal - C4 model (Structurizr DSL)
 * C4 Level 1 - System Context: who uses the portal, and which external systems does it depend on or serve?
 * C4 Level 2 - Containers: which deployable parts make up the portal, what does each own, and how do they talk?
 *   Business data (cases, documents, profile, delegations) stays with agencies and registries and is read live
 *   through the Agency integration service; the portal keeps only a minimal database.
 * Edit online: paste into https://structurizr.com/dsl
 * Export SVG:  structurizr-cli export -workspace diagrams/workspace.dsl -format plantuml -output <tmp>
 *              plantuml -tsvg <tmp>/structurizr-<view key>.puml, then copy to diagrams/<view key>.svg
 */
workspace "Citizen Services Portal" "Architecture model of the Citizen Services Portal." {

    !identifiers hierarchical

    model {
        resident = person "Resident / Citizen" "Finds, requests and tracks public services; exchanges documents and messages; signs documents; sees who accessed their data. May act as a delegate for another person within a given scope."
        admin = person "Administrator / Helpdesk" "Supports residents and operates the portal with role-limited access to case data."
        auditor = person "Auditor / Oversight body" "Verifies that citizen data was accessed and processed lawfully."
        ops = person "Operations / Security team" "Monitors service health and responds to incidents and security events."
        agencyStaff = person "Agency staff" "Processes requests for their own organization's services." "External"

        portal = softwareSystem "Citizen Services Portal" "Single digital entry point for public services: service catalogue, case management, document exchange, signing workflow, notifications, delegation, audit and transparency, regulated public APIs." {
            group "Front end and entry" {
                web = container "Citizen web app" "Localized citizen UI." "Web SPA"
                backoffice = container "Back-office web app" "Helpdesk, admin and audit review." "Web SPA"
                gateway = container "API gateway" "Token validation, scopes, rate limits, API versioning." "Gateway"
            }
            group "Business services" {
                iam = container "Identity & access" "eID login, sessions, role and delegation checks." "Service"
                catalogue = container "Catalogue & profile" "Service catalogue, preferences." "Service"
                cases = container "Case service" "Submits requests, shows live case status." "Service"
                docs = container "Document service" "Upload, scan, deliver, download." "Service"
                signingSvc = container "Signing service" "eID signing flow." "Service"
            }
            group "Shared services" {
                bus = container "Message broker" "Delivery queue, notification and audit events." "Async messaging" "Queue"
                integration = container "Agency integration" "Per-agency adapters, data minimization, retries." "Adapters"
                notifySvc = container "Notification service" "Inbox, email/SMS/push dispatch." "Service"
                audit = container "Audit service" "Audit trail, transparency queries." "Service"
                scanner = container "Antivirus scanner" "Scans every upload before it is accepted." "Scan engine"
            }
            portalDb = container "Portal DB (minimal)" "Preferences, catalogue config, API clients." "Relational DB" "Database"
            docStore = container "Temporary doc store" "Quarantine and transit only." "Object storage" "Database"
            auditStore = container "Audit store" "Append-only, tamper-evident records." "Append-only store" "Database"
            observability = container "Observability" "Health, alerts, security events." "Monitoring, logs, tracing"
        }

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

        // Container level. Colour tags by kind of interaction: user, route, sync, async, external, store.
        resident -> portal.web "Uses" "" "user"
        admin -> portal.backoffice "Uses" "" "user"
        auditor -> portal.backoffice "Reviews audit evidence" "" "user"
        thirdParty -> portal.gateway "Calls public APIs" "" "user"
        ops -> portal.observability "Monitors" "" "user"
        portal.web -> portal.gateway "API calls" "" "user"
        portal.backoffice -> portal.gateway "API calls" "" "user"

        portal.gateway -> portal.iam "Authenticates, authorizes" "" "route"
        portal.gateway -> portal.catalogue "Routes" "" "route"
        portal.gateway -> portal.cases "Routes" "" "route"
        portal.gateway -> portal.docs "Routes" "" "route"
        portal.gateway -> portal.signingSvc "Routes" "" "route"
        portal.gateway -> portal.audit "Transparency queries" "" "route"

        portal.iam -> portal.integration "Verifies delegations" "" "sync"
        portal.catalogue -> portal.integration "Reads profile" "" "sync"
        portal.cases -> portal.integration "Reads case status" "" "sync"
        portal.docs -> portal.integration "Delivers, fetches documents" "" "sync"
        portal.signingSvc -> portal.docs "Gets document" "" "sync"
        portal.docs -> portal.scanner "Scans uploads" "" "sync"

        portal.cases -> portal.bus "Publishes requests" "" "async"
        portal.bus -> portal.integration "Queued delivery" "" "async"
        portal.bus -> portal.notifySvc "Case events" "" "async"
        portal.bus -> portal.audit "Audit events (all services)" "" "async"

        portal.iam -> idp "Authenticates residents via" "" "external"
        portal.signingSvc -> signing "Signs, validates via" "" "external"
        portal.integration -> agencies "Requests, status, documents" "" "external"
        portal.integration -> registries "Minimal lookups" "" "external"
        portal.notifySvc -> notify "Sends via" "" "external"

        portal.catalogue -> portal.portalDb "Reads, writes" "" "store"
        portal.iam -> portal.portalDb "Reads, writes" "" "store"
        portal.docs -> portal.docStore "Stores temporarily" "" "store"
        portal.audit -> portal.auditStore "Appends" "" "store"
    }

    views {
        systemContext portal "c4_system_context" {
            title "System Context - Citizen Services Portal"
            include *
            include agencyStaff
            autoLayout tb 250 200
        }

        container portal "c4_containers" {
            title "Containers - Citizen Services Portal"
            include *
            exclude "notify -> resident"
            autoLayout tb 150 200
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
            element "Boundary" {
                color #1168bd
                metadata false
            }
            element "Container" {
                background #438dd5
            }
            element "Database" {
                shape Cylinder
            }
            element "Queue" {
                shape Pipe
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
            relationship "user" {
                color #1f77b4
            }
            relationship "route" {
                color #555555
            }
            relationship "sync" {
                color #ff7f0e
            }
            relationship "async" {
                color #9467bd
            }
            relationship "external" {
                color #d62728
            }
            relationship "store" {
                color #2ca02c
            }
        }
    }

}
