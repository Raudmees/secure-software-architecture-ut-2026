/*
 * Citizen Services Portal - C4 model (Structurizr DSL)
 * C4 Level 1 - System Context: who uses the portal, and which external systems does it depend on or serve?
 * C4 Level 2 - Containers: which deployable parts make up the portal, what does each own, and how do they talk?
 *   Business data (cases, documents, profile, delegations) stays with agencies and registries and is read live
 *   through the Agency integration service; the portal keeps only a minimal database.
 * C4 Deployment, one view per deployment environment:
 *   Production:  which infrastructure runs each container, which network zones does traffic cross, and how is
 *                each part made redundant?
 *   Test:        the same zones, infrastructure and security controls as production, with fewer and smaller
 *                instances, synthetic data and the test environments of the external systems.
 *   Development: the whole portal on one developer's computer, with stubs in place of the external systems.
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
                integration = container "Agency integration" "Agency API, registry adapters, data minimization, retries." "Adapters"
                audit = container "Audit service" "Audit trail, transparency queries." "Service"
                portalDb = container "Portal DB (minimal)" "Preferences, catalogue configuration, API client registrations, sessions, notification inbox and submission records." "Relational DB" "Database"
                docStore = container "Temporary file store" "Quarantine and transit only." "Object storage" "Database"
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
        // Interface arrows carry the interface name from docs/interface_inventory.adoc.
        resident -> portal.web "Uses" "HTTPS" "user"
        admin -> portal.backoffice "Uses" "HTTPS" "user"
        auditor -> portal.backoffice "Reviews audit evidence" "HTTPS" "user"
        thirdParty -> portal.gateway "Portal Third-party API" "HTTPS, OAuth 2.0 client credentials" "user"
        ops -> portal.observability "Monitors" "HTTPS" "user"
        portal.web -> portal.gateway "Portal Citizen API" "HTTPS/JSON" "user"
        portal.backoffice -> portal.gateway "Portal Back-office API" "HTTPS/JSON" "user"

        portal.gateway -> portal.iam "Identity & Access API" "HTTPS/JSON" "route"
        portal.gateway -> portal.backend "Portal Backend API" "HTTPS/JSON" "route"
        portal.gateway -> portal.audit "Audit Transparency API" "HTTPS/JSON" "route"

        portal.iam -> portal.integration "Mandate Check API" "HTTPS/JSON" "sync"
        portal.backend -> portal.integration "Integration Data API" "HTTPS/JSON" "sync"
        portal.backend -> portal.scanner "Scans uploads" "Scan API" "sync"
        portal.integration -> portal.backend "Delivery Report API" "HTTPS/JSON" "sync"

        portal.backend -> portal.bus "Submission Queue, Audit Event Stream" "Message queue" "async"
        portal.bus -> portal.integration "Submission Queue" "Message queue" "async"
        portal.bus -> portal.audit "Audit Event Stream (all containers)" "Message queue" "async"

        portal.iam -> idp "eID Login API" "OIDC" "external"
        portal.backend -> signing "Digital Signing API" "HTTPS API" "external"
        portal.integration -> agencies "Agency API" "HTTPS API, mTLS" "external"
        portal.integration -> registries "External Registry APIs" "HTTPS API, mTLS" "external"
        portal.backend -> notify "Notification Provider APIs" "HTTPS provider APIs" "external"

        portal.backend -> portal.portalDb "Reads, writes" "SQL" "store"
        portal.iam -> portal.portalDb "Reads, writes" "SQL" "store"
        portal.backend -> portal.docStore "Stores files temporarily" "Object storage API" "store"
        portal.integration -> portal.docStore "Reads files for delivery" "Object storage API" "store"
        portal.audit -> portal.auditStore "Appends" "SQL" "store"

        // Deployment: where the containers run in each environment (Production, Test, Development).
        // Technologies on the deployment nodes are working assumptions. Structurizr copies every container
        // relationship to the container instances of each environment.

        // Production. Traffic that crosses the portal network edge is drawn through the infrastructure nodes,
        // so the deployment view hides the direct copies of those relationships (tags "user" and "external").
        production = deploymentEnvironment "Production" {

            residentDevice = deploymentNode "Resident's device" "Computer, tablet or phone of a resident or delegate." "Windows, macOS, Linux, Android or iOS" {
                browser = deploymentNode "Web browser" "" "Chrome, Firefox, Safari or Edge" {
                    webApp = containerInstance portal.web
                }
            }

            staffDevice = deploymentNode "Staff or auditor workstation" "Device of a helpdesk worker, administrator or auditor. Reaches the portal only through the staff VPN." "Windows or macOS with VPN client" {
                browser = deploymentNode "Web browser" "" "Chrome, Firefox or Edge" {
                    backofficeApp = containerInstance portal.backoffice
                }
            }

            thirdPartyHosting = deploymentNode "Third-party provider hosting" "Run by each registered API client, outside the portal operator's control." "Provider's own infrastructure" {
                thirdPartyClient = softwareSystemInstance thirdParty
            }

            govCloud = deploymentNode "Estonian Government Cloud" "State private cloud (Riigipilv). Assumed to have three availability zones (zones) in Estonia, so all data stays in the country." "Private cloud (IaaS), 3 zones" {

                edge = deploymentNode "Edge network (DMZ)" "The only zone reachable from the internet. Holds no personal data." "Network zone" {
                    waf = infrastructureNode "Web application firewall" "Drops floods, bot traffic and oversized requests, and limits requests per client IP." "WAF with DDoS protection"
                    lb = infrastructureNode "Public load balancer" "Terminates public TLS and spreads requests over the zones." "HTTPS load balancer"
                    vpn = infrastructureNode "Staff VPN gateway" "Admits only staff and auditor devices with a VPN certificate. Back-office traffic never uses the public entry." "IPsec VPN gateway"
                    webContent = infrastructureNode "Web content server" "Serves the files of the Citizen web app and the Back-office web app. Holds no data." "nginx"
                }

                egressZone = deploymentNode "Egress zone" "Outbound traffic only." "Network zone" {
                    egress = infrastructureNode "Egress proxy" "The only way out. Lets each service reach only its own external destinations, from fixed IP addresses that agencies and registries allow. TLS passes through, so mTLS ends in the calling pod." "HTTPS forward proxy"
                }

                cluster = deploymentNode "Portal application cluster" "Stateless services. Each runs at least 3 pods, one per zone, and scales out on load. Network policies allow only the calls on the container diagram; every pod has its own mTLS service identity." "Kubernetes" {
                    gatewayPod = deploymentNode "API gateway pod" "" "Kubernetes pod" "" 3 {
                        gateway = containerInstance portal.gateway
                    }
                    iamPod = deploymentNode "Identity & access pod" "" "Kubernetes pod" "" 3 {
                        iam = containerInstance portal.iam
                    }
                    backendPod = deploymentNode "Portal backend pod" "Also runs the outbox relay (ADR-0005)." "Kubernetes pod" "" 3 {
                        backend = containerInstance portal.backend
                    }
                    integrationPod = deploymentNode "Agency integration pod" "" "Kubernetes pod" "" 3 {
                        integration = containerInstance portal.integration
                    }
                    auditPod = deploymentNode "Audit service pod" "" "Kubernetes pod" "" 3 {
                        audit = containerInstance portal.audit
                    }
                    scannerPod = deploymentNode "Antivirus scanner pod" "Separate node pool with no outbound network access. Virus signatures are updated by rolling out a new image." "Kubernetes pod" "" 3 {
                        scanner = containerInstance portal.scanner
                    }
                    collector = infrastructureNode "Telemetry collector" "Collects metrics, logs and traces from every pod and drops tokens and personal identification codes." "OpenTelemetry Collector"
                }

                data = deploymentNode "Data zone" "Reachable only from the application cluster. All storage is encrypted at rest." "Network zone" {
                    dbServer = deploymentNode "Portal DB server" "Primary and synchronous standby in different zones, with automatic failover and encrypted point-in-time backups." "PostgreSQL on Linux VM" "" 2 {
                        portalDb = containerInstance portal.portalDb
                    }
                    objectStorage = deploymentNode "Object storage" "Replicated over the zones and not backed up, so a deleted file leaves no copy. A lifecycle rule deletes files older than 7 days." "S3-compatible object storage" {
                        docStore = containerInstance portal.docStore
                    }
                    brokerNode = deploymentNode "Message broker node" "One node per zone. Quorum queues keep every message on all three nodes on encrypted disks; per-queue permissions enforce IF-9 and IF-10." "RabbitMQ on Linux VM" "" 3 {
                        bus = containerInstance portal.bus
                    }
                }

                auditEnv = deploymentNode "Audit environment" "Separate cloud tenant and network with its own administrators. Portal administrators cannot change or delete audit records." "Separate Government Cloud tenant" {
                    auditDbServer = deploymentNode "Audit store server" "Primary and standby in different zones. The Audit service may only insert; daily backups go to write-once (WORM) storage." "PostgreSQL on Linux VM" "" 2 {
                        auditStore = containerInstance portal.auditStore
                    }
                }

                opsZone = deploymentNode "Operations zone" "Reached by the Operations / Security team through the staff VPN." "Network zone" {
                    obsStack = deploymentNode "Observability stack" "Keeps no tokens, personal identification codes or document content." "Prometheus, Loki, Tempo, Grafana" {
                        observability = containerInstance portal.observability
                    }
                }
            }

            nationalTrust = deploymentNode "National trust services" "Run by the state and by trust service providers, outside the portal operator's control." "Providers' own infrastructure" {
                idpService = softwareSystemInstance idp
                signingService = softwareSystemInstance signing
                registryServices = softwareSystemInstance registries
            }

            agencyHosting = deploymentNode "Agency data centres" "Each agency hosts its own endpoint of the Agency API." "Agencies' own infrastructure" {
                agencyServices = softwareSystemInstance agencies
            }

            notifyHosting = deploymentNode "Notification provider hosting" "Outside the portal operator's control." "Providers' own infrastructure" {
                notifyServices = softwareSystemInstance notify
            }

            // Ingress: residents and third parties enter through the WAF, staff and auditors through the VPN.
            production.residentDevice.browser.webApp -> production.govCloud.edge.waf "Loads app files, calls Portal Citizen API" "HTTPS" "ingress"
            production.thirdPartyHosting.thirdPartyClient -> production.govCloud.edge.waf "Portal Third-party API" "HTTPS, OAuth 2.0 client credentials" "ingress"
            production.govCloud.edge.waf -> production.govCloud.edge.lb "Forwards allowed requests" "HTTPS" "ingress"
            production.govCloud.edge.lb -> production.govCloud.edge.webContent "Forwards app file requests" "HTTPS" "ingress"
            production.govCloud.edge.lb -> production.govCloud.cluster.gatewayPod.gateway "Forwards API requests" "HTTPS" "ingress"
            production.staffDevice.browser.backofficeApp -> production.govCloud.edge.vpn "Loads app files, calls Portal Back-office API" "HTTPS over IPsec" "ingress"
            production.govCloud.edge.vpn -> production.govCloud.edge.webContent "Forwards app file requests" "HTTPS" "ingress"
            production.govCloud.edge.vpn -> production.govCloud.cluster.gatewayPod.gateway "Forwards back-office API requests" "HTTPS" "ingress"

            // Egress: every call to an external system leaves through the egress proxy.
            production.govCloud.cluster.iamPod.iam -> production.govCloud.egressZone.egress "eID Login API" "OIDC" "egress"
            production.govCloud.cluster.backendPod.backend -> production.govCloud.egressZone.egress "Digital Signing API, Notification Provider APIs" "HTTPS" "egress"
            production.govCloud.cluster.integrationPod.integration -> production.govCloud.egressZone.egress "Agency API, External Registry APIs" "HTTPS, mTLS" "egress"
            production.govCloud.egressZone.egress -> production.nationalTrust.idpService "eID Login API" "OIDC" "egress"
            production.govCloud.egressZone.egress -> production.nationalTrust.signingService "Digital Signing API" "HTTPS" "egress"
            production.govCloud.egressZone.egress -> production.nationalTrust.registryServices "External Registry APIs" "HTTPS, mTLS" "egress"
            production.govCloud.egressZone.egress -> production.agencyHosting.agencyServices "Agency API" "HTTPS, mTLS" "egress"
            production.govCloud.egressZone.egress -> production.notifyHosting.notifyServices "Notification Provider APIs" "HTTPS" "egress"

            // Telemetry
            production.govCloud.cluster.collector -> production.govCloud.opsZone.obsStack.observability "Sends metrics, logs and traces" "OTLP over TLS" "telemetry"
        }

        // Test (staging): the same zones, infrastructure nodes, technologies and security controls as
        // production, so a release that passes here behaves the same there. It differs only in size
        // (one zone, fewer and smaller instances), in data (synthetic only) and in the external systems
        // it reaches (their test environments). Keep the structure in step with production.
        test = deploymentEnvironment "Test" {

            testerDevice = deploymentNode "Tester's workstation" "Device of a developer, tester or product owner. Reaches the test environment only from an allow-listed IP address; the back office also needs the staff VPN." "Windows, macOS or Linux with VPN client" {
                browser = deploymentNode "Web browser" "" "Chrome, Firefox, Safari or Edge" {
                    backofficeApp = containerInstance portal.backoffice
                    webApp = containerInstance portal.web
                }
            }

            thirdPartyHosting = deploymentNode "Third-party provider hosting" "Test systems of registered third-party providers and the team's own test client, admitted by IP address." "Provider's own infrastructure" {
                thirdPartyClient = softwareSystemInstance thirdParty
            }

            govCloud = deploymentNode "Estonian Government Cloud" "Same cloud as production, in a separate test tenant with its own network, accounts and secrets. Uses one zone." "Private cloud (IaaS), test tenant, 1 zone" {

                edge = deploymentNode "Edge network (DMZ)" "The only zone reachable from outside. Holds no data." "Network zone" {
                    waf = infrastructureNode "Web application firewall" "Same rules as production. Also admits only allow-listed IP addresses, so the test environment is closed to the public." "WAF with DDoS protection"
                    lb = infrastructureNode "Public load balancer" "Terminates TLS and spreads requests over the pods." "HTTPS load balancer"
                    vpn = infrastructureNode "Staff VPN gateway" "Admits only tester and staff devices with a VPN certificate. Back-office traffic never uses the public entry." "IPsec VPN gateway"
                    webContent = infrastructureNode "Web content server" "Serves the files of the Citizen web app and the Back-office web app. Holds no data." "nginx"
                }

                egressZone = deploymentNode "Egress zone" "Outbound traffic only." "Network zone" {
                    egress = infrastructureNode "Egress proxy" "The only way out. Same rules as production, but each service reaches only the test environments of its external systems; production endpoints are blocked." "HTTPS forward proxy"
                }

                cluster = deploymentNode "Portal application cluster" "Same images, configuration, network policies and mTLS service identities as production. Each service runs 2 small pods, the fewest that still show faults between instances, and does not scale out." "Kubernetes" {
                    gatewayPod = deploymentNode "API gateway pod" "" "Kubernetes pod" "" 2 {
                        gateway = containerInstance portal.gateway
                    }
                    iamPod = deploymentNode "Identity & access pod" "" "Kubernetes pod" "" 2 {
                        iam = containerInstance portal.iam
                    }
                    backendPod = deploymentNode "Portal backend pod" "Also runs the outbox relay (ADR-0005). Two pods show whether two relays publish the same row twice." "Kubernetes pod" "" 2 {
                        backend = containerInstance portal.backend
                    }
                    integrationPod = deploymentNode "Agency integration pod" "" "Kubernetes pod" "" 2 {
                        integration = containerInstance portal.integration
                    }
                    auditPod = deploymentNode "Audit service pod" "" "Kubernetes pod" "" 2 {
                        audit = containerInstance portal.audit
                    }
                    scannerPod = deploymentNode "Antivirus scanner pod" "Separate node pool with no outbound network access, as in production." "Kubernetes pod" {
                        scanner = containerInstance portal.scanner
                    }
                    collector = infrastructureNode "Telemetry collector" "Collects metrics, logs and traces from every pod and drops tokens and personal identification codes." "OpenTelemetry Collector"
                }

                data = deploymentNode "Data zone" "Reachable only from the application cluster. All storage is encrypted at rest. Holds synthetic test data only, never a copy of production data." "Network zone" {
                    dbServer = deploymentNode "Portal DB server" "One small instance without a standby or point-in-time backups. The data is recreated from seed scripts." "PostgreSQL on Linux VM" {
                        portalDb = containerInstance portal.portalDb
                    }
                    objectStorage = deploymentNode "Object storage" "Not replicated. Same 7-day lifecycle rule as production." "S3-compatible object storage" {
                        docStore = containerInstance portal.docStore
                    }
                    brokerNode = deploymentNode "Message broker node" "One node with the same queues and per-queue permissions as production. Messages are kept on one encrypted disk." "RabbitMQ on Linux VM" {
                        bus = containerInstance portal.bus
                    }
                }

                auditEnv = deploymentNode "Audit environment" "Separate tenant with its own administrators, as in production, so the separation is tested too." "Separate Government Cloud tenant" {
                    auditDbServer = deploymentNode "Audit store server" "One instance. The Audit service may only insert, as in production. No write-once backups." "PostgreSQL on Linux VM" {
                        auditStore = containerInstance portal.auditStore
                    }
                }

                opsZone = deploymentNode "Operations zone" "Reached through the staff VPN." "Network zone" {
                    obsStack = deploymentNode "Observability stack" "Same stack as production, with small disks and short retention." "Prometheus, Loki, Tempo, Grafana" {
                        observability = containerInstance portal.observability
                    }
                }
            }

            nationalTrust = deploymentNode "National trust services (test)" "Test environments of the state and the trust service providers. They issue test identities and test signatures only." "Providers' test environments" {
                idpService = softwareSystemInstance idp
                signingService = softwareSystemInstance signing
                registryServices = softwareSystemInstance registries
            }

            agencyHosting = deploymentNode "Agency test environments" "Each agency hosts a test endpoint of the Agency API." "Agencies' test environments" {
                agencyServices = softwareSystemInstance agencies
            }

            notifyHosting = deploymentNode "Notification provider sandboxes" "Sandbox accounts that deliver messages only to test recipients." "Providers' test environments" {
                notifyServices = softwareSystemInstance notify
            }

            // Ingress: testers and third-party test clients enter through the WAF, the back office through the VPN.
            test.testerDevice.browser.webApp -> test.govCloud.edge.waf "Loads app files, calls Portal Citizen API" "HTTPS" "ingress"
            test.thirdPartyHosting.thirdPartyClient -> test.govCloud.edge.waf "Portal Third-party API" "HTTPS, OAuth 2.0 client credentials" "ingress"
            test.govCloud.edge.waf -> test.govCloud.edge.lb "Forwards allowed requests" "HTTPS" "ingress"
            test.govCloud.edge.lb -> test.govCloud.edge.webContent "Forwards app file requests" "HTTPS" "ingress"
            test.govCloud.edge.lb -> test.govCloud.cluster.gatewayPod.gateway "Forwards API requests" "HTTPS" "ingress"
            test.testerDevice.browser.backofficeApp -> test.govCloud.edge.vpn "Loads app files, calls Portal Back-office API" "HTTPS over IPsec" "ingress"
            test.govCloud.edge.vpn -> test.govCloud.edge.webContent "Forwards app file requests" "HTTPS" "ingress"
            test.govCloud.edge.vpn -> test.govCloud.cluster.gatewayPod.gateway "Forwards back-office API requests" "HTTPS" "ingress"

            // Egress: every call to an external test environment leaves through the egress proxy.
            test.govCloud.cluster.iamPod.iam -> test.govCloud.egressZone.egress "eID Login API" "OIDC" "egress"
            test.govCloud.cluster.backendPod.backend -> test.govCloud.egressZone.egress "Digital Signing API, Notification Provider APIs" "HTTPS" "egress"
            test.govCloud.cluster.integrationPod.integration -> test.govCloud.egressZone.egress "Agency API, External Registry APIs" "HTTPS, mTLS" "egress"
            test.govCloud.egressZone.egress -> test.nationalTrust.idpService "eID Login API" "OIDC" "egress"
            test.govCloud.egressZone.egress -> test.nationalTrust.signingService "Digital Signing API" "HTTPS" "egress"
            test.govCloud.egressZone.egress -> test.nationalTrust.registryServices "External Registry APIs" "HTTPS, mTLS" "egress"
            test.govCloud.egressZone.egress -> test.agencyHosting.agencyServices "Agency API" "HTTPS, mTLS" "egress"
            test.govCloud.egressZone.egress -> test.notifyHosting.notifyServices "Notification Provider APIs" "HTTPS" "egress"

            // Telemetry
            test.govCloud.cluster.collector -> test.govCloud.opsZone.obsStack.observability "Sends metrics, logs and traces" "OTLP over TLS" "telemetry"
        }

        // Development: the whole portal on one developer's computer. There is no network edge and the
        // external systems are stubs, so the copied container relationships are drawn as they are.
        development = deploymentEnvironment "Development" {

            devComputer = deploymentNode "Developer's computer" "Runs the whole portal for one developer. Every port listens on localhost only. Holds synthetic test data and no secrets of the test or production environment." "macOS, Linux or Windows" {

                webDevServer = infrastructureNode "Web dev server" "Serves the files of both web apps and reloads them when the code changes." "Local development server"

                browser = deploymentNode "Web browser" "" "Chrome, Firefox, Safari or Edge" {
                    backofficeApp = containerInstance portal.backoffice
                    webApp = containerInstance portal.web
                }

                docker = deploymentNode "Local Docker environment" "Starts everything below from one Compose file, each part once. A local development CA, which exists only on this computer, issues the TLS and mTLS certificates." "Docker Compose" {
                    gateway = containerInstance portal.gateway
                    iam = containerInstance portal.iam
                    backend = containerInstance portal.backend
                    integration = containerInstance portal.integration
                    audit = containerInstance portal.audit
                    scanner = containerInstance portal.scanner
                    collector = infrastructureNode "Telemetry collector" "Same rules as production: drops tokens and personal identification codes." "OpenTelemetry Collector"

                    dbServer = deploymentNode "Portal DB server" "Filled with synthetic test data by a seed script." "PostgreSQL in Docker" {
                        portalDb = containerInstance portal.portalDb
                    }
                    objectStorage = deploymentNode "Object storage" "Same 7-day lifecycle rule as production." "S3-compatible storage in Docker" {
                        docStore = containerInstance portal.docStore
                    }
                    brokerNode = deploymentNode "Message broker node" "One node with the same queues and per-queue permissions as production." "RabbitMQ in Docker" {
                        bus = containerInstance portal.bus
                    }
                    auditDbServer = deploymentNode "Audit store server" "Its own server and credentials, as in production. The Audit service may only insert." "PostgreSQL in Docker" {
                        auditStore = containerInstance portal.auditStore
                    }
                    obsStack = deploymentNode "Observability stack" "Optional. Started only when the developer needs dashboards or traces." "Prometheus, Loki, Tempo, Grafana in Docker" {
                        observability = containerInstance portal.observability
                    }
                    stubs = deploymentNode "Stub external systems" "Stand in for every external system with scripted answers, so no call leaves the computer and no real credentials are needed. A test can make a stub fail or answer late." "Mock server in Docker" {
                        idpStub = softwareSystemInstance idp
                        signingStub = softwareSystemInstance signing
                        registryStub = softwareSystemInstance registries
                        agencyStub = softwareSystemInstance agencies
                        notifyStub = softwareSystemInstance notify
                    }
                }
            }

            development.devComputer.browser.webApp -> development.devComputer.webDevServer "Loads app files" "HTTPS" "ingress"
            development.devComputer.browser.backofficeApp -> development.devComputer.webDevServer "Loads app files" "HTTPS" "ingress"
            development.devComputer.docker.collector -> development.devComputer.docker.obsStack.observability "Sends metrics, logs and traces" "OTLP" "telemetry"
        }
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

        deployment portal "Production" "c4_deployment_production" {
            title "Deployment (Production) - Citizen Services Portal"
            description "Where does each container run in production, which network zones and infrastructure does traffic cross, and how is each part made redundant? xN is the number of instances of a node."
            include *
            // Hide the direct copies of relationships that are drawn through the WAF, VPN or egress proxy.
            exclude "relationship.tag==user"
            exclude "relationship.tag==external"
        }

        deployment portal "Test" "c4_deployment_test" {
            title "Deployment (Test) - Citizen Services Portal"
            description "Where does each container run in the test environment, and how does it differ from production? Same zones, infrastructure and security controls; one zone with fewer and smaller instances; synthetic data; test environments of the external systems. xN is the number of instances of a node."
            include *
            // Hide the direct copies of relationships that are drawn through the WAF, VPN or egress proxy.
            exclude "relationship.tag==user"
            exclude "relationship.tag==external"
        }

        deployment portal "Development" "c4_deployment_development" {
            title "Deployment (Development) - Citizen Services Portal"
            description "What runs on a developer's computer, and what stands in for the production infrastructure and the external systems? Everything runs once, on localhost, with synthetic data and stubs."
            include *
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
            element "Deployment Node" {
                background #ffffff
                color #000000
                stroke #888888
                metadata true
            }
            element "Infrastructure Node" {
                background #ffffff
                color #000000
                stroke #555555
                metadata true
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
            relationship "ingress" {
                color #1f77b4
            }
            relationship "egress" {
                color #d62728
            }
            relationship "telemetry" {
                color #8c564b
            }
        }
    }

}
