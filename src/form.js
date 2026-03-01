import React from "react";
import ReactDOM from "react-dom";
import { useState } from "react";
import { pushToFirebase, useUserState } from "./utilities/firebase.js";
import { App } from "./App";
import { MySelection, Food2url } from "./select.js";
import { FaTrashAlt, FaArrowCircleLeft } from "react-icons/fa";
import { ToastContainer, toast, Slide } from 'react-toastify';
import { expiry_dates } from '../src/components/expiry_dates.js';
import DropdownButton from 'react-bootstrap/DropdownButton';
import Dropdown from 'react-bootstrap/Dropdown';
import 'react-toastify/dist/ReactToastify.css';
import './form.css'
export const AddButton = () => (
  <>
    <button
      type="button"
      className="btn"
      onClick={() =>
        ReactDOM.render(<MyForm />, document.getElementById("root"))
      }
    >
      { window.innerWidth > 600 ? "Add food" : "add"}
    </button>
  </>
);

const SetExpirationDate = (day) => {
  var experation = new Date();
  var setDays = day;
  experation.setDate(experation.getDate() + setDays);
  var writtenEXP = experation.toLocaleString('sv', { timeZone: 'America/Chicago' }).substring(0, 10);
  return writtenEXP;

}

const MyForm = (param) => {
  var today = new Date().toLocaleString('sv', { timeZone: 'America/Chicago' }).substring(0, 10);
  var na = "";
  //console.log(param.n);

  const [name, setName] = useState(na);
  const [buyDate, setbuyDate] = useState(today);
  const [expDate, setexpDate] = useState(today);
  const [icon, setIcon] = useState("");
  const user = useUserState();
  const [section, setSection] = useState('fridge');
  const [isSuggested, setIsSuggested] = useState(false);

  const onSubmit = (e) => {
    e.preventDefault();
    //Scan name here to set experation date
    if (!name || !buyDate || !expDate) {
      notification('info');
      return;
    }

    if (new Date(expDate).getTime() - new Date(buyDate).getTime() < 0) {
      notification('date');
      return;
    }

    update({ icon, name, buyDate, expDate, user, section });

    if (name !== "") {
      notification('add');
    }

    setName("");
    setbuyDate(today);
    setexpDate(today);
    setSection('fridge');
  };


  const suggestExpiry = (foodName, foodSection, isSuggested) => {
    setName(foodName)
    setSection(foodSection)
    if (foodName.length < 2)
      setIsSuggested(false)
    return expiry_dates.map((exp_food, index) => {
      var newday = new Date();
      var exp_food_lower = exp_food.name.toLowerCase();
      for (let i = exp_food_lower.length; i > 0 && isSuggested === false && i > exp_food_lower.length * 0.7; i--) {
        var substr = exp_food_lower.substring(0, i);
        if (substr === foodName.toLowerCase()) {
          if (foodSection === 'fridge') {
            newday = SetExpirationDate(parseInt(exp_food.fridge))
          }
          else if (foodSection === 'shelf') {
            newday = SetExpirationDate(parseInt(exp_food.shelf))
          }
          else {
            newday = SetExpirationDate(parseInt(exp_food.freezer))
          }
          notification('suggested', exp_food.name);
          setIsSuggested(true)
          setexpDate(newday);
        }
      }
      return
    })
  }

  return (
    <div className="container">
      <ToastContainer transition={Slide} />
      <form className="add-form" onSubmit={onSubmit}>
        <div><FaArrowCircleLeft onClick={() => back()} size={40} style={{ color: 'rgb(121, 148, 25)', cursor: 'pointer' }} /> </div>
        <div className="form-control">
          <label>Food Name</label>
          <input
            type="text"
            placeholder = {window.innerWidth > 400 ? "Add food" : "Add"} 
            value={name}
            onChange={(e) => suggestExpiry(e.target.value, section, isSuggested)}
          />
        </div>
        <div className="form-control">
          <label>Purchase Date</label>
          <input
            type="date"
            placeholder="Purchase Date"
            value={buyDate}
            onChange={(e) => setbuyDate(e.target.value)}
          />
        </div>
        <div className="form-control">
          <label>Expiration Date</label>
          <input
            type="date"
            placeholder="Expiration Date"
            value={expDate}
            onChange={(e) => setexpDate(e.target.value)}
          />
        </div>
        <DropdownButton
          title={section}
          id="dropdown-menu-align-left"
          onSelect={(e) => suggestExpiry(name, e, false)}
        >
          <Dropdown.Item eventKey="fridge">fridge</Dropdown.Item>
          <Dropdown.Item eventKey="shelf">shelf</Dropdown.Item>
          <Dropdown.Item eventKey="freezer">freezer</Dropdown.Item>
        </DropdownButton>
        {/* <div>
          <MySelection icon={icon} setIcon={setIcon} />
        </div> */}

        <input type="submit" value="Add item" className="btn btn-block" />

      </form>
    </div>
  );
};

export const EditMyForm = (param) => {
  var experation = new Date().toLocaleString('sv', { timeZone: 'America/Chicago' }).substring(0, 10);
  var today = new Date().toLocaleString('sv', { timeZone: 'America/Chicago' }).substring(0, 10);
  var na = "";
  var Editing = false;

  if (param.date) {
    today = param.date;
    Editing = true;
  }

  if (param.exp) {
    experation = param.exp;
  }

  if (param.n) {
    na = param.n;
  }

  //console.log(param.n);

  const suggestExpiry = (foodName, foodSection, isSuggested) => {
    setName(foodName)
    setSection(foodSection)
    if (foodName.length < 2)
      setIsSuggested(false)
    return expiry_dates.map((exp_food, index) => {
      var newday = new Date();
      var exp_food_lower = exp_food.name.toLowerCase();
      for (let i = exp_food_lower.length; i > 0 && isSuggested === false && i > exp_food_lower.length * 0.7; i--) {
        var substr = exp_food_lower.substring(0, i);
        if (substr === foodName.toLowerCase()) {
          if (foodSection === 'fridge') {
            newday = SetExpirationDate(parseInt(exp_food.fridge))
          }
          else if (foodSection === 'shelf') {
            newday = SetExpirationDate(parseInt(exp_food.shelf))
          }
          else {
            newday = SetExpirationDate(parseInt(exp_food.freezer))
          }
          notification('suggested', exp_food.name);
          setIsSuggested(true)
          setexpDate(newday);
        }
      }
      return
    })
  }

  const toUsed = () => {
    const namex = {
      icon: emoji(name),
      // icon: Food2url(icon),
      name: name,
      buyDate: buyDate,
      expDate: expDate,
      section: 'used',
    };
    const id = Math.round(Math.random() * 100000);
    const newFood = { id, ...namex };
    pushToFirebase(newFood, user);
    ReactDOM.render(<App />, document.getElementById("root"));
  }

  const [name, setName] = useState(na);
  const [buyDate, setbuyDate] = useState(today);
  const [expDate, setexpDate] = useState(experation);
  const [icon, setIcon] = useState("");
  const user = useUserState();
  const [section, setSection] = useState('fridge');
  const [isSuggested, setIsSuggested] = useState(false);

  const onSubmit = (e) => {
    e.preventDefault();

    if (!name || !buyDate || !expDate) {
      notification('info');
      return;
    }

    if (new Date(expDate).getTime() - new Date(buyDate).getTime() < 0) {
      notification('date');
      return;
    }

    update({ icon, name, buyDate, expDate, user, section });

    if (name !== "") {
    }

    back();
  };

  return (
    <div className="container">
      <ToastContainer transition={Slide} />
      <form className="add-form" onSubmit={onSubmit}>
        <div className="form-control">
          <label>Food Name</label>
          <input
            type="text"
            placeholder="Add Food"
            value={name}
            onChange={(e) => suggestExpiry(e.target.value, section, isSuggested)}
          />
        </div>
        <div className="form-control">
          <label>Purchase Date</label>
          <input
            type="date"
            placeholder="Purchase Date"
            value={buyDate}
            onChange={(e) => setbuyDate(e.target.value)}
          />
        </div>
        <div className="form-control">
          <label>Expiration Date</label>
          <input
            type="date"
            placeholder="Expiration Date"
            value={expDate}
            onChange={(e) => setexpDate(e.target.value)}
          />
        </div>

        <DropdownButton
          title={section}
          id="dropdown-menu-align-left"
          onSelect={(e) => suggestExpiry(name, e, false)}
        >
          <Dropdown.Item eventKey="fridge">fridge</Dropdown.Item>
          <Dropdown.Item eventKey="shelf">shelf</Dropdown.Item>
          <Dropdown.Item eventKey="freezer">freezer</Dropdown.Item>
        </DropdownButton>

        <input type="submit" value="Finish Editing" className="btn btn-block" />
        <br />
        <div className="btn2 btn-block" onClick={() => toUsed()}>
          <center><FaTrashAlt size={20} style={{ color: 'white', cursor: 'pointer', margin: 4 }} /></center>
        </div>
      </form>
    </div>
  );
};

export const RecMyForm = (param) => {
  var experation = new Date().toLocaleString('sv', { timeZone: 'America/Chicago' }).substring(0, 10);
  var today = new Date().toLocaleString('sv', { timeZone: 'America/Chicago' }).substring(0, 10);
  var na = "";
  var Editing = false;

  if (param.date) {
    today = param.date;
    Editing = true;
  }

  if (param.exp) {
    experation = param.exp;
  }

  if (param.n) {
    na = param.n;
  }

  var sec = param.sec || 'fridge';

  const suggestExpiry = (foodName, foodSection, isSuggested) => {
    setName(foodName)
    setSection(foodSection)
    if (foodName.length < 2)
      setIsSuggested(false)
    return expiry_dates.map((exp_food, index) => {
      var newday = new Date();
      var exp_food_lower = exp_food.name.toLowerCase();
      for (let i = exp_food_lower.length; i > 0 && isSuggested === false && i > exp_food_lower.length * 0.7; i--) {
        var substr = exp_food_lower.substring(0, i);
        if (substr === foodName.toLowerCase()) {
          if (foodSection === 'fridge') {
            newday = SetExpirationDate(parseInt(exp_food.fridge))
          }
          else if (foodSection === 'shelf') {
            newday = SetExpirationDate(parseInt(exp_food.shelf))
          }
          else {
            newday = SetExpirationDate(parseInt(exp_food.freezer))
          }
          notification('suggested', exp_food.name);
          setIsSuggested(true)
          setexpDate(newday);
        }
      }
      return
    })
  }

  const [name, setName] = useState(na);
  const [buyDate, setbuyDate] = useState(today);
  const [expDate, setexpDate] = useState(experation);
  const [icon, setIcon] = useState("");
  const user = useUserState();
  const [section, setSection] = useState(sec);
  const [isSuggested, setIsSuggested] = useState(false);

  const onSubmit = (e) => {
    e.preventDefault();

    if (!name || !buyDate || !expDate) {
      notification('info');
      return;
    }

    if (new Date(expDate).getTime() - new Date(buyDate).getTime() < 0) {
      notification('date');
      return;
    }

    update({ icon, name, buyDate, expDate, user, section });

    back();
  };

  return (
    <div className="container">
      <ToastContainer transition={Slide} />
      <form className="add-form" onSubmit={onSubmit}>
        <div className="form-control">
          <label>Food Name</label>
          <input
            type="text"
            placeholder="Add Food"
            value={name}
            onChange={(e) => suggestExpiry(e.target.value, section, isSuggested)}
          />
        </div>
        <div className="form-control">
          <label>Purchase Date</label>
          <input
            type="date"
            placeholder="Purchase Date"
            value={buyDate}
            onChange={(e) => setbuyDate(e.target.value)}
          />
        </div>
        <div className="form-control">
          <label>Expiration Date</label>
          <input
            type="date"
            placeholder="Expiration Date"
            value={expDate}
            onChange={(e) => setexpDate(e.target.value)}
          />
        </div>

        <DropdownButton
          title={section}
          id="dropdown-menu-align-left"
          onSelect={(e) => suggestExpiry(name, e, false)}
        >
          <Dropdown.Item eventKey="fridge">fridge</Dropdown.Item>
          <Dropdown.Item eventKey="shelf">shelf</Dropdown.Item>
          <Dropdown.Item eventKey="freezer">freezer</Dropdown.Item>
        </DropdownButton>

        <input type="submit" value="Recycle" className="btn btn-block" />
        <br />
        <div className="btn2 btn-block" onClick={() => back()}>
          <center><FaTrashAlt size={20} style={{ color: 'white', cursor: 'pointer', margin: 4 }} /></center>
        </div>
      </form>
    </div>
  );
};


const emoji = (value) => {

  const name = require("emoji-name-map");
  var noemoji = name.get("shopping_cart"); // default icon
  var value_lower = value.toLowerCase();
  for (let i = value_lower.length + 1; i > value_lower.length - 3; i--) {
    var substr = value_lower.substring(0, i);
    var substr_emoji = name.get(substr);
    if (typeof substr_emoji != "undefined") {
      return substr_emoji;
    }
  }
  return noemoji;
};

//Update the state with new items and
export const update = ({ icon, name, buyDate, expDate, user, section }) => {
  const namex = {
    icon: emoji(name),
    // icon: Food2url(icon),
    name: name,
    buyDate: buyDate,
    expDate: expDate,
    section: section,
  };

  const id = Math.round(Math.random() * 100000);
  const newFood = { id, ...namex };
  pushToFirebase(newFood, user);
};


const back = () => {
  ReactDOM.render(<App />, document.getElementById("root"));
};

export const notification = (type, data) => {
  switch (type) {
    case 'expp':
      toast.info(data, {
        position: "top-center",
        autoClose: 2000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        progress: undefined,
        theme: "colored"
      }
      );
      break;

    case 'add':
      toast.success('Item added!', {
        position: "top-center",
        autoClose: 3000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        progress: undefined,
        theme: "colored",
      }
      );
      break;
    case 'edit':
      toast.success('Item edited!', {
        position: "top-center",
        autoClose: 3000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        delay: 500,
        progress: undefined,
        theme: "colored"
      }
      );
      break;
    case 'del':
      toast.success('Item deleted!', {
        position: "top-center",
        autoClose: 2000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        progress: undefined,
        theme: "colored"
      }
      );
      break;
    case 'suggested':
      toast.success(`Expiration date of ${data} suggested`, {
        position: "top-center",
        autoClose: 2000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        progress: undefined,
        theme: "colored"
      }
      );
      break;
    case 'info':
      toast.warn('Please complete all the information!', {
        position: "top-center",
        autoClose: 2000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        progress: undefined,
        theme: "colored"
      }
      );
      break;
    case 'date':
      toast.error('Expiration date should be after purchase date!', {
        position: "top-center",
        autoClose: 2000,
        hideProgressBar: true,
        closeOnClick: true,
        pauseOnHover: true,
        draggable: false,
        progress: undefined,
        theme: "colored"
      }
      );
      break;
  }
}
