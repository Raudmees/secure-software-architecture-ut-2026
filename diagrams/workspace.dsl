/*
 * Citizen Services Portal - C4 model (Structurizr DSL)
 * C4 Level 1 - System Context: who uses the portal, and which external systems does it depend on or serve?
 * C4 Level 2 - Containers: which deployable parts make up the portal, what does each own, and how do they talk?
 *   Business data (cases, documents, profile, delegations) stays with agencies and registries and is read live
 *   through the Agency integration service; the portal keeps only a minimal database.
 * Edit online: paste into https://structurizr.com/dsl
 * Export SVG:  render with Structurizr (docker run -it --rm --user "$(id -u):$(id -g)" -p 8080:8080
 *              -v <repo>/diagrams:/usr/local/structurizr structurizr/structurizr local),
 *              open http://localhost:8080, arrange each diagram, export it as SVG and save it as
 *              diagrams/<view key>.svg. Commit workspace.json together with workspace.dsl,
 *              because it stores the manual layout.
 */
workspace "Citizen Services Portal" "Architecture model of the Citizen Services Portal." {

    !identifiers hierarchical

    model {
        resident = person "Resident / Citizen" "Finds, requests and tracks public services; exchanges documents and messages; signs documents; sees who accessed their data. May act as a delegate for another person within a given scope."
        auditor = person "Auditor / Oversight body" "Verifies that citizen data was accessed and processed lawfully."

        group "Portal operator" {
            admin = person "Administrator / Helpdesk" "Supports residents and operates the portal with role-limited access to case data."
            ops = person "Operations / Security team" "Monitors service health and responds to incidents and security events."
            portal = softwareSystem "Citizen Services Portal" "Single digital entry point for public services: service catalogue, case management, document exchange, signing workflow, notifications, delegation, audit and transparency, regulated public APIs." {
                web = container "Citizen web app" "Localized citizen UI." "Web SPA"
                backoffice = container "Back-office web app" "Helpdesk, admin and audit review." "Web SPA"
                gateway = container "API gateway" "Token validation, scopes, rate limits, API versioning." "Gateway"
                iam = container "Identity & access" "eID login, sessions, role and delegation checks." "Service"
                backend = container "Portal backend" "Service catalogue and preferences, case submission and status, document upload and download, eID signing workflow, notification dispatch and inbox." "Modular backend service"
                bus = container "Message broker" "Delivery queue for requests to agencies (contains personal data: encrypted, access-controlled, durable) and audit events." "Async messaging" "Queue"
                integration = container "Agency integration" "Per-agency adapters, data minimization, retries." "Adapters"
                audit = container "Audit service" "Audit trail, transparency queries." "Service"
                portalDb = container "Portal DB (minimal)" "Preferences, catalogue configuration, API client registrations, sessions and notification inbox." "Relational DB" "Database"
                docStore = container "Temporary doc store" "Quarantine and transit only." "Object storage" "Database"
                scanner = container "Antivirus scanner" "Scans every upload in isolation before it is accepted." "Scan engine"
                group "Audit environment" {
                    auditStore = container "Audit store" "Append-only, tamper-evident audit records." "Relational DB" "Database"
                }
                observability = container "Observability" "Health, alerts, security events." "Monitoring, logs, tracing"
            }
        }

        group "Agency trust domain" {
            agencyStaff = person "Agency staff" "Processes requests for their own organization's services." "External"
            agencies = softwareSystem "Agency back-end e-services" "Systems of the agencies that deliver and decide the services. Separate trust domain." "External"
        }

        group "National trust services" {
            idp = softwareSystem "National eID / OIDC identity provider" "Authenticates residents. The portal trusts only configured providers and validates every token." "External"
            signing = softwareSystem "Digital signing service" "Creates and validates legally binding eID signatures." "External"
            registries = softwareSystem "External registries" "Authoritative data such as population, business and mandate/delegation registries." "External"
        }

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
        resident -> portal.web "Uses" "HTTPS" "user"
        admin -> portal.backoffice "Uses" "HTTPS" "user"
        auditor -> portal.backoffice "Reviews audit evidence" "HTTPS" "user"
        thirdParty -> portal.gateway "Calls public APIs" "HTTPS, OAuth 2.0 client credentials" "user"
        ops -> portal.observability "Monitors" "HTTPS" "user"
        portal.web -> portal.gateway "API calls" "HTTPS/JSON" "user"
        portal.backoffice -> portal.gateway "API calls" "HTTPS/JSON" "user"

        portal.gateway -> portal.iam "Authenticates, authorizes" "HTTPS/JSON" "route"
        portal.gateway -> portal.backend "Routes API calls" "HTTPS/JSON" "route"
        portal.gateway -> portal.audit "Transparency queries" "HTTPS/JSON" "route"

        portal.iam -> portal.integration "Verifies delegations" "HTTPS/JSON" "sync"
        portal.backend -> portal.integration "Reads profile and case status; delivers and fetches documents" "HTTPS/JSON" "sync"
        portal.backend -> portal.scanner "Scans uploads" "Scan API" "sync"

        portal.backend -> portal.bus "Publishes requests and events" "Message queue" "async"
        portal.bus -> portal.integration "Queued delivery" "Message queue" "async"
        portal.bus -> portal.audit "Audit events (all containers)" "Message queue" "async"

        portal.iam -> idp "Authenticates residents via" "OIDC" "external"
        portal.backend -> signing "Signs, validates via" "HTTPS API" "external"
        portal.integration -> agencies "Requests, status, documents" "HTTPS API, mTLS" "external"
        portal.integration -> registries "Minimal lookups" "HTTPS API, mTLS" "external"
        portal.backend -> notify "Sends notifications via" "HTTPS provider APIs" "external"

        portal.backend -> portal.portalDb "Reads, writes" "SQL" "store"
        portal.iam -> portal.portalDb "Reads, writes" "SQL" "store"
        portal.backend -> portal.docStore "Stores documents temporarily" "Object storage API" "store"
        portal.audit -> portal.auditStore "Appends" "SQL" "store"
    }

    views {
        systemContext portal "c4_system_context" {
            title "System Context - Citizen Services Portal"
            description "Who uses the Citizen Services Portal, and which external systems does it depend on or serve? Dashed boxes are trust domains."
            include *
            include agencyStaff
        }

        container portal "c4_containers" {
            title "Containers - Citizen Services Portal"
            description "Which deployable parts make up the portal, where is its data stored, and how do they communicate across trust boundaries?"
            include *
            exclude "notify -> resident"
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
                height 480
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
