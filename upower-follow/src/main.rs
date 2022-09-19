use serde::Serialize;
use upower_dbus::{BatteryState, DeviceProxy, UPowerProxy};
use zbus::export::futures_util::StreamExt;
use zbus::{Connection, PropertyStream, Result, ResultAdapter};

#[derive(Debug, Serialize)]
struct BatStatus {
    percentage: f64,
    charging: bool,
    icon: String,
}

#[derive(Debug)]
struct BatStatusStream<'c> {
    current_status: BatStatus,
    state_stream: PropertyStream<'c, <Result<BatteryState> as ResultAdapter>::Ok>,
    percentage_stream: PropertyStream<'c, <Result<f64> as ResultAdapter>::Ok>,
    icon_stream: PropertyStream<'c, <Result<String> as ResultAdapter>::Ok>,
}

impl<'c> BatStatusStream<'c> {
    pub async fn from(device: &DeviceProxy<'c>) -> Result<BatStatusStream<'c>> {
        // TODO: Batch the awaits
        Ok(BatStatusStream {
            current_status: BatStatus {
                percentage: device.percentage().await?,
                charging: device.state().await? == BatteryState::Charging, // TODO: There's def
                // better ways
                icon: device.icon_name().await?,
            },
            state_stream: device.receive_state_changed().await,
            percentage_stream: device.receive_percentage_changed().await,
            icon_stream: device.receive_icon_name_changed().await,
        })
    }

    pub async fn next(&mut self) -> Result<&BatStatus> {
        tokio::select! {
            Some(status) = self.state_stream.next() => {
                self.current_status.charging = status.get().await? == BatteryState::Charging;
            }
            Some(icon) = self.icon_stream.next() => {
                self.current_status.icon = icon.get().await?;
            }
            Some(percentage) = self.percentage_stream.next() => {
                self.current_status.percentage = percentage.get().await?;
            }
        }

        Ok(&self.current_status)
    }

    pub fn get(&self) -> &BatStatus {
        &self.current_status
    }
}

#[tokio::main]
async fn main() {
    let conn = Connection::system().await.unwrap();
    let proxy = UPowerProxy::new(&conn).await.unwrap();
    let display = proxy.get_display_device().await.unwrap();

    let device = DeviceProxy::builder(&conn)
        .path(display)
        .unwrap()
        .build()
        .await
        .unwrap();

    let mut stream = BatStatusStream::from(&device).await.unwrap();

    println!("{}", serde_json::to_string(stream.get()).unwrap());
    loop {
        println!(
            "{}",
            serde_json::to_string(stream.next().await.unwrap()).unwrap()
        );
    }
}
