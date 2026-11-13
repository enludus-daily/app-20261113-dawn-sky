import Foundation

/// 空のメモ：撮ったあとに 1 つ出す（手で用意した 40 本。日によって変わる）
enum SkyNotes {
    struct Note: Sendable {
        let ja: String
        let en: String
        var text: String { tr(ja, en) }
    }

    static func note(for day: String) -> Note {
        let seed = day.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        return all[Int(seed % UInt32(all.count))]
    }

    static let all: [Note] = [
        Note(ja: "空が青いのは、短い波長の青い光ほど空気の粒にはね返されやすいから（レイリー散乱）。", en: "The sky is blue because air scatters short blue wavelengths far more than red (Rayleigh scattering)."),
        Note(ja: "朝焼けが赤いのは、低い太陽の光が長い空気の道を通るうちに、青い光が散ってしまうから。", en: "Dawn is red because low sunlight crosses so much air that most of the blue gets scattered away."),
        Note(ja: "日の出の前に空が明るくなる時間を「薄明」と呼ぶ。太陽が地平線の下 6 度までが市民薄明。", en: "The glow before sunrise is twilight; civil twilight lasts until the sun is 6° below the horizon."),
        Note(ja: "朝の光を浴びると、体内時計がリセットされ、夜に眠くなる時刻も前にずれやすい。", en: "Morning light resets your body clock, nudging tonight's sleepiness earlier too."),
        Note(ja: "起きてすぐ外の光を見るのは、室内の照明よりずっと強い光を目に入れること。曇りの日でも室内の数倍明るい。", en: "Outdoor light right after waking is far stronger than indoor lighting — even on cloudy days, several times brighter."),
        Note(ja: "朝の空気は昼より澄んでいることが多い。地面が冷えて、ちりを巻き上げる風が弱いため。", en: "Morning air is often clearer than midday: the ground is cool and there's less wind to stir up dust."),
        Note(ja: "空が紫に見える瞬間は、青い空と赤い光が混ざっている。数分しか続かない。", en: "A violet sky is blue sky mixed with red light — it lasts only a few minutes."),
        Note(ja: "雲は水や氷のつぶ。どの色の光もほぼ同じように散らすので、白や灰色に見える。", en: "Clouds are water and ice droplets that scatter all colors about equally, so they look white or grey."),
        Note(ja: "朝焼けの日は天気が崩れやすい、という言い伝えがある。西から来る雲が東の光を受けるため。", en: "Old sayings warn that a red morning brings rain: clouds arriving from the west catch the eastern light."),
        Note(ja: "冬の空が濃い青に見えるのは、空気が乾いていて水の粒が少ないから。", en: "Winter skies look deep blue because dry air carries fewer water droplets."),
        Note(ja: "秋の空が高く見えるのは、雲ができる高さが上がり、空気が澄むため。", en: "Autumn skies feel higher because clouds form higher up and the air is clearer."),
        Note(ja: "日の出の時刻は、太陽の上の端が地平線に触れた瞬間のこと。", en: "Sunrise is the moment the top edge of the sun touches the horizon."),
        Note(ja: "地平線の近くの空ほど白っぽい。光が長い距離を通り、いろいろな色が混ざるから。", en: "The sky near the horizon is paler: light travels farther there and the colors blend."),
        Note(ja: "雨上がりの空が澄んでいるのは、雨がちりを洗い流したから。", en: "Skies after rain look crisp because the rain washed the dust out of the air."),
        Note(ja: "霧は地面の近くにできた雲。風のない、冷えた朝にできやすい。", en: "Fog is cloud at ground level, most common on cold, windless mornings."),
        Note(ja: "春がすみの白さは、花粉や黄砂、水蒸気が空にただようため。", en: "Spring haze comes from pollen, dust, and moisture drifting in the air."),
        Note(ja: "起きる時刻を毎日そろえると、目覚ましが鳴る前に目が覚めやすくなる。", en: "Waking at the same time daily makes it likelier you'll wake before the alarm."),
        Note(ja: "週末の寝坊は「社会的時差ぼけ」と呼ばれ、月曜の朝をつらくする原因のひとつ。", en: "Weekend sleep-ins cause 'social jet lag' — one reason Monday mornings feel so hard."),
        Note(ja: "朝の 15 分は、体温と覚醒が上がりはじめる時間。カーテンを開けるのがいちばん手軽な合図。", en: "The first 15 minutes are when body temperature and alertness start to climb. Opening the curtains is the easiest cue."),
        Note(ja: "夏至の日の出は、冬至より 2 時間ほど早い（東京）。", en: "In Tokyo, sunrise at the summer solstice is about two hours earlier than at the winter solstice."),
        Note(ja: "空の色は、毎朝ちがう。同じ場所の同じ時刻でも、雲と湿り気で別の色になる。", en: "No two morning skies match — same place, same time, but clouds and humidity change everything."),
        Note(ja: "青と緑のあいだの空は、とても澄んだ空気と低い太陽がそろったときに見える。", en: "Blue-green skies appear when very clear air meets a low sun."),
        Note(ja: "金色の光は、日の出の後の短い時間だけ。影が長く、色があたたかい。", en: "Golden light only lasts a short while after sunrise: long shadows, warm color."),
        Note(ja: "人は暗い色より明るい色を「朝」と感じやすい。だから朝のパレットは淡くなる。", en: "We read pale, light colors as 'morning' — that's why morning palettes look soft."),
        Note(ja: "曇りの日の空は単調に見えるが、撮ると灰色にも青み・黄み・紫みがある。", en: "Overcast skies look flat, but photos reveal greys tinted blue, yellow, or violet."),
        Note(ja: "日の出の方角は季節で動く。冬は南寄り、夏は北寄りから太陽がのぼる。", en: "Sunrise drifts with the seasons — south of east in winter, north of east in summer."),
        Note(ja: "朝の光は、目の奥のメラノプシンという光の受け手を通して、体内時計に届く。", en: "Morning light reaches your body clock via melanopsin, a light sensor at the back of the eye."),
        Note(ja: "飛行機雲が長く残る朝は、上空が湿っている。", en: "If contrails linger in the morning, the upper air is humid."),
        Note(ja: "うろこ雲・いわし雲は、秋の高い空によく出る。", en: "Mackerel skies — rows of small clouds — are common in high autumn skies."),
        Note(ja: "日の出の数分前に、空がいちばん色を変える。撮るならその時間。", en: "The sky changes color fastest in the minutes just before sunrise. That's the moment to shoot."),
        Note(ja: "寒い朝に吐く息が白いのは、息の水蒸気が冷えて小さな雲になるから。", en: "Your breath turns white on cold mornings because its vapor cools into a tiny cloud."),
        Note(ja: "起きて最初にスマホの通知より空を見ると、一日の始まりを自分で選べる。", en: "Looking at the sky before your notifications lets you choose how the day begins."),
        Note(ja: "朝焼けと夕焼けは同じ仕組み。ただ朝は空気が冷えていて、色が澄みやすい。", en: "Sunrise and sunset glow work the same way, but cooler morning air often makes colors cleaner."),
        Note(ja: "雪の朝が明るいのは、雪が光をよく返して、空と地面の両方から光が来るから。", en: "Snowy mornings feel bright because snow reflects light — it comes from both sky and ground."),
        Note(ja: "雲の切れ間から差す光の筋は「天使のはしご」と呼ばれる。", en: "Rays of light through gaps in the clouds are called crepuscular rays — or 'angel ladders'."),
        Note(ja: "ブルーアワーは、日の出前に空が深い青になる時間。街の灯りと空の明るさがそろう。", en: "The blue hour is the deep-blue spell before sunrise, when city lights and sky brightness balance."),
        Note(ja: "夜明けの空に一番遅くまで残る星は、たいてい金星（明けの明星）。", en: "The last 'star' to fade at dawn is usually Venus, the morning star."),
        Note(ja: "1 年の朝をすべて並べると、季節が色の帯になって見える。", en: "Line up a year of mornings and the seasons show up as bands of color."),
        Note(ja: "朝に体を動かすより、まず光を浴びるほうが体内時計には効く。", en: "For your body clock, getting light first thing matters more than exercise."),
        Note(ja: "寝坊した日も、空はそこにある。欠けたマスは、明日の朝を少し楽しみにするための余白。", en: "The sky's still there on days you sleep in. A missing square is just room to look forward to tomorrow."),
    ]
}
