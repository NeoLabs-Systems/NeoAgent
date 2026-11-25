import React from 'react';
export const App = () => {
  const s = "</div>";
  return <div className="x">{s}{'}'}</div>;
};
export default class Page extends React.Component {
  render() { return <App />; }
}
