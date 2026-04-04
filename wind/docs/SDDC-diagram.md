# SDDC

```mermaid
graph TD
    subgraph Management_Plane [Management Plane]
        AZ[Azure Arc]
        CLF[Cloudflare]
        MON[Azure Monitor / AMA]
    end

    subgraph Compute_Fabric [Compute & Storage]
        direction LR
        S1[mini-me-intel-01]
        S2[mini-me-intel-02]
    end

    subgraph Virtualization [Docker and KVM]
        direction TD
        V1[Docker]
        V2[KVM]
        V3[Container Network]
        V3 --- V4
        V3 --- V5
        V4[VLAN 1] --> NSX
        V5[VLAN 60] --> NSX
        
    end

    subgraph Networking_Overlay [Logical Networking]
        direction TD
        NSX[UDMPRO]
        T0[VLAN 1]
        T1[VLAN 60]
        
    end

    subgraph Applications [Management apps]
        M1[N8N] --- V1
        M2[NGINX]--- V1
        M3[MAAS] --- V1
        M4[GRAFANA] --- V1
    end

    AZ --> S1
    AZ --> S2
    MON --- S1
    MON --- S2
    CLF --> V3
