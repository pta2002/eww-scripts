use futures::join;
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

fn is_charging(state: BatteryState) -> bool {
    return state == BatteryState::FullyCharged || state == BatteryState::Charging;
}

impl<'c> BatStatusStream<'c> {
    pub async fn from(device: &DeviceProxy<'c>) -> Result<BatStatusStream<'c>> {
        let results = join!(
            device.percentage(),
            device.state(),
            device.icon_name(),
            device.receive_state_changed(),
            device.receive_percentage_changed(),
            device.receive_icon_name_changed()
        );

        Ok(BatStatusStream {
            current_status: BatStatus {
                percentage: results.0?,
                charging: is_charging(results.1?),
                icon: results.2?,
            },
            state_stream: results.3,
            percentage_stream: results.4,
            icon_stream: results.5,
        })
    }

    pub async fn next(&mut self) -> Result<&BatStatus> {
        tokio::select! {
            Some(status) = self.state_stream.next() => {
                self.current_status.charging = is_charging(status.get().await?);
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
