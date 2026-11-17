import { useState } from 'react'

function App() {
  const [count, setCount] = useState(0)

  return (
    <main className="min-h-screen bg-base-200 flex items-center justify-center p-4">
      <div className="card bg-base-100 w-full max-w-md shadow-xl">
        <div className="card-body items-center text-center">
          <h1 className="card-title text-3xl">Orcavoice</h1>
          <p className="text-base-content/70">Vite + React + Tailwind + daisyUI</p>
          <div className="card-actions mt-4">
            <button className="btn btn-primary" onClick={() => setCount((c) => c + 1)}>
              Count is {count}
            </button>
          </div>
        </div>
      </div>
    </main>
  )
}

export default App
